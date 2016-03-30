# TODO: add @specs.
# TODO: >, <, >=, <=
defmodule Rational do
  @vsn "0.6"


  @inline_math_functions [*: 2, /: 2, -: 2, -: 1, +: 2, +: 1]
  @overridden_math_functions [div: 2, abs: 1] ++ @inline_math_functions
  @rational_operator [<|>: 2]


  import Kernel, except: [div: 2, abs: 1, *: 2, /: 2, -: 2, -: 1, +: 2, +: 1]

  # TODO: Add option to not load the operator.

  # Does not import any overridden math functions
  defmacro __using__(without_overridden_math: true) do
    quote do
      import Rational, except: unquote([to_float: 1] ++ @overridden_math_functions)
    end
  end

  # Does not import the overridden inline math *, /, functions:
  defmacro __using__(without_inline_math: true) do
    quote do
      import Rational, except: unquote([to_float: 1] ++ @inline_math_functions)
    end
  end

  defmacro __using__(_) do
    quote do
      import Kernel, except: unquote(@overridden_math_functions)
      import Rational, except: [to_float: 1]
    end
  end


  @doc """
  A Rational number is defined as a numerator and a denominator.
  Both the numerator and the denominator are integers.
  If you want to match for a rational number, you can do so by matching against this Struct.

  Note that *directly manipulating* the struct, however, is usually a bad idea, as then there are no validity checks, nor wil the rational be simplified.

  Use `Rational.<|>/2` or `Rational.new/2` instead.
  """
  defstruct numerator: 0, denominator: 1
  @type t :: %Rational{numerator: integer(), denominator: pos_integer()}

  @doc """
  Creates a new Rational number.
  This number is simplified to the most basic form automatically.
  If the most basic form has the format `_ <|> 1`, it is returned in integer form.

  Rational numbers with a `0` as denominator are not allowed.

  Note that it is recommended to use integer numbers for the numerator and the denominator.

  ## Floats

  Tl;Dr: *If possible, don't use them.*

  Using Floats for the numerator or denominator is possible, however, because base-2 floats cannot represent all base-10 fractions properly, the results might be different from what you might expect.
  See [The Perils of Floating Point](http://www.lahey.com/float.htm) for more information about this.

  Passed floats are rounded to `#{Application.get_env(:rational, :max_float_to_rational_digits)}` digits, to make the result match expectations better.
  This number can be changed by adding `max_float_to_rational_digits: 10` to your config file.

  See Rational.FloatConversion.float_to_rational/2 for more info about float -> rational parsing.

  As Float-parsing is done by converting floats to a digit-list representation first, this is also far slower than when using integers or rationals.

  ## Examples

      iex> 1 <|> 2
      1 <|> 2
      iex> 100 <|> 300
      1 <|> 3
      iex> 1.5 <|> 4
      3 <|> 8
  """
  def numerator <|> denominator

  def _numerator <|> 0 do
    raise ArithmeticError
  end

  def numerator <|> denominator when is_integer(numerator) and is_integer(denominator) do 
    %Rational{numerator: numerator, denominator: denominator}
    |> simplify
    |> remove_denominator_if_integer
  end

  def numerator <|> denominator when is_float(numerator) do
    div(Rational.FloatConversion.float_to_rational(numerator), denominator)
  end

  def numerator <|> denominator when is_float(denominator) do
    div(numerator, Rational.FloatConversion.float_to_rational(denominator))
  end

  def (numerator=%Rational{}) <|> (denominator=%Rational{}) do
    div(numerator, denominator)
  end

  def numerator <|> denominator do
    div(numerator, denominator)
  end

  @doc """
  Prefix-version of `numerator <|> denominator`.
  Useful when `<|>` is not available (for instance, when already in use by another module)
  
  """
  def new(numerator, denominator), do: numerator <|> denominator

  @doc """
  Returns the absolute version of the given number (which might be an integer, float or Rational).

  ## Examples

      iex>Rational.abs(-5 <|> 2)
      5 <|> 2
  """
  def abs(number) when is_number(number), do: Kernel.abs(number)
  def abs(%Rational{numerator: numerator, denominator: denominator}), do: Kernel.abs(numerator) <|> denominator

  @doc """
  Returns the sign of the given number (which might be an integer, float or Rational)
 
  This is:
  
   - 1 if the number is positive.
   - -1 if the number is negative.
   - 0 if the number is zero.

  """
  def sign(%Rational{numerator: numerator}) when Kernel.>(numerator, 0), do: 1
  def sign(%Rational{numerator: numerator}) when Kernel.<(numerator, 0), do: Kernel.-(1)
  def sign(number) when is_number(number) and Kernel.>(number, 0), do: 1
  def sign(number) when is_number(number) and Kernel.<(number, 0), do: Kernel.-(1)
  def sign(number) when is_number(number), do: 0

  @doc """
  Converts the passed *number* as a Rational number, and extracts its denominator.
  For integers returns the passed number itself.

  """
  def numerator(number) when is_integer(number), do: number
  def numerator(number) when is_float(number), do: numerator(Rational.FloatConversion.float_to_rational(number))
  def numerator(%Rational{numerator: numerator}), do: numerator

  @doc """
  Treats the passed *number* as a Rational number, and extracts its denominator.
  For integers, returns `1`.
  """
  def denominator(number) when is_number(number), do: 1
  def denominator(%Rational{denominator: denominator}), do: denominator


  @doc """
  Longhand for Rational.+/2
  """
  def add(a, b)

  def add(a, b) when is_integer(a) and is_integer(b), do: Kernel.+(a, b)
  
  def add(a, b) when is_float(a), do: add(Rational.FloatConversion.float_to_rational(a), b) 
  
  def add(a, b) when is_float(b), do: add(a, Rational.FloatConversion.float_to_rational(b)) 

  def add(a, %Rational{numerator: b, denominator: lcm}) when is_integer(a), do: Kernel.+(a * lcm, b) <|> lcm
  def add(%Rational{numerator: a, denominator: lcm}, b) when is_integer(b), do: Kernel.+(b * lcm, a) <|> lcm

  def add(%Rational{numerator: a, denominator: lcm}, %Rational{numerator: c, denominator: lcm}) do
    Kernel.+(a, c) <|> lcm
  end
  
  def add(%Rational{numerator: a, denominator: b}, %Rational{numerator: c, denominator: d}) do
    Kernel.+((a * d), (c * b)) <|> (b * d)  
  end
  

  @doc """
  Adds two numbers, one or both of which might be integers, floats or rationals.

  The result is converted to a rational if applicable.

  ## Examples

      iex> 2 + 3
      5
      iex> 2.3 + 0.3
      13 <|> 5
  """
  def a + b when is_integer(a) and is_integer(b), do: Kernel.+(a, b)
  def a + b, do: add(a, b)
  
  @doc """
  Longhand for Rational.-/2
  """
  def sub(a, b) when is_integer(a) and is_integer(b), do: Kernel.-(a, b)
  def sub(a, b), do: add(a, negate(b))

  @doc """
  Subtracts *b* from *a*. One or both might be integers, floats or rationals.

  The result is converted to a rational if applicable.

  ## Examples

      iex> 2 - 3
      -1
      iex> 2.3 - 0.3
      2
      iex> 2.3 - 0.1
      11 <|> 5
      iex> (2 <|> 3) - (1 <|> 5)
  """
  def a - b when is_integer(a) and is_integer(b), do: Kernel.-(a, b)
  def a - b, do: add(a, negate(b))

  @doc """
  Longhand for `Rational.-/1`
  """
  def negate(num) 
  
  def negate(num) when is_integer(num), do: Kernel.-(num)
  
  def negate(num) when is_float(num), do: negate(Rational.FloatConversion.float_to_rational(num))

  def negate(%Rational{numerator: numerator, denominator: denominator}) do
    %Rational{numerator: Kernel.-(numerator), denominator: denominator}
  end


  @doc """
  Unary minus. Inverts the sign of the given *num*, which might be an integer, float or rational.
  Floats are converted to Rationals before inverting the sign.


  ## Examples

      iex> -10
      -10
      iex> -10.0
      -10
      iex> -10.1
      -101 <|> 10
      iex> -(5 <|> 3)
      -5 <|> 3
      iex> -123.456
      -15432 <|> 125
  """
  def (-num) when is_integer(num), do: Kernel.-(num)
  
  def (-num), do: negate(num)


  @doc """
  Unary plus. Returns *num*.
  Coerces the number to a rational if it is a float.
  """
  def (+num) when is_integer(num), do: Kernel.+(num)
  def (+num) when is_float(num), do: Rational.FloatConversion.float_to_rational(num)
  def (+num), do: num



  @doc """
  Longhand for Rational.*/2
  """
  def mul(number1, number2)
  def mul(number1, number2) when is_number(number1) and is_number(number2), do: Kernel.*(number1, number2)

  def mul(%Rational{numerator: numerator, denominator: denominator}, number) when is_number(number) do
    Kernel.*(numerator, number) <|> (denominator)
  end

  def mul(number, %Rational{numerator: numerator, denominator: denominator}) when is_number(number) do
    Kernel.*(numerator, number) <|> (denominator)
  end


  def mul(%Rational{numerator: numerator1, denominator: denominator1}, %Rational{numerator: numerator2, denominator: denominator2}) do
    Kernel.*(numerator1, numerator2) <|> Kernel.*(denominator1, denominator2)
  end

  @doc """
  Multiplies two numbers. (one or both of which might be integers, floats or rationals)

  ## Examples

      iex> (2 <|> 3) *  10)
      20 <|> 3
      iex> ( 1 <|> 3) * (1 <|> 2)
      1 <|> 6
  """
  def a * b

  def a * b when is_number(a) and is_number(b), do: Kernel.*(a, b)

  def a * b, do: mul(a, b)

  @doc """
  Longhand for Rational.//2

  """
  def div(a, b)

  def div(a, b) when is_number(a) and is_integer(b), do: a <|> b

  def div(%Rational{numerator: numerator, denominator: denominator}, number) when is_number(number) do
    numerator <|> Kernel.*(denominator, number)
  end

  # 6 / (2 <|> 3) == 6 * (3 <|> 2)
  def div(number, %Rational{numerator: numerator, denominator: denominator}) when is_number(number) do
    mul(number, denominator <|> numerator)
  end


  def div(%Rational{numerator: numerator1, denominator: denominator1}, %Rational{numerator: numerator2, denominator: denominator2}) do
    Kernel.*(numerator1, denominator2) <|> Kernel.*(denominator1, numerator2)
  end

  @doc """
  Divides a number by another number, one or both of which might be integers, floats or rationals.

  The function will return integers whenever possible, and otherwise returns a rational number.

  ## Examples

      iex> Rational.div(1 <|> 3, 2)
      1 <|> 6
      iex> Rational.div( 2 <|> 3, 8 <|> 3)
      1 <|> 4

  """
  def a / b
  
  def a / b when is_number(a) and is_integer(b), do:  a <|> b

  def a / b, do: div(a, b)

  defmodule ComparisonError do
    defexception message: "These things cannot be compared."
  end

  

  def compare(%Rational{numerator: a, denominator: b}, %Rational{numerator: c, denominator: d}) do
      compare(Kernel.*(a, d), Kernel.*(b, c))
  end

  def compare(%Rational{numerator: numerator, denominator: denominator}, b) do
      compare(numerator, Kernel.*(b, denominator))
  end

  def compare(a, %Rational{numerator: numerator, denominator: denominator}) do
      compare(Kernel.*(a, denominator), numerator)
  end


  # Compares any other value that Elixir/Erlang can understand.
  def compare(a, b) do
    cond do
      a > b ->  1
      a < b -> -1
      a == b -> 0
      true  ->  raise ComparisonError, "These things cannot be compared: #{a} , #{b}"
    end
  end

  @doc """
  Returns true if *a* is larger than *b*
  """
  defmacro a > b do
    quote do
      compare(unquote(a), unquote(b)) == 1
    end  
  end

  @doc """
  True if *a* is larger than or equal to *b*
  """
  def gt?(a, b), do: compare(a, b) ==  1

  @doc """
  True if *a* is smaller than *b*
  """
  def lt?(a, b), do: compare(a, b) == -1

  @doc """
  True if *a* is larger than or equal to *b*
  """
  def gte?(a, b), do: compare(a, b) >=  0

  @doc """
  True if *a* is smaller than or equal to *b*
  """
  def lte?(a, b), do: compare(a, b) <=  0

  @doc """
  returns *x* to the *n* th power.

  *x* is allowed to be an integer, rational or float (in the last case, this is first converted to a rational).

  Will give the answer as a rational number when applicable.
  Note that the exponent *n* is only allowed to be an integer.

  (so it is not possible to compute roots using this function.)

  ## Examples

      iex>pow(2, 4)
      16
      iex>pow(2, -4)
      1 <|> 16
      iex>pow(3 <|> 2, 10)
      59049 <|> 1024
  """
  @spec pow(number()|Rational.t(), pos_integer()) :: number() | Rational.t()
  def pow(x, n)

  #Convert Float to Rational.
  def pow(x, n) when is_float(x), do: pow(Rational.FloatConversion.float_to_rational(x), n)

  # Small powers
  def pow(x, 1), do: x
  def pow(x, 2), do: x * x
  def pow(x, 3), do: x * x * x
  def pow(x, n) when is_integer(n), do: _pow(x, n)

  # Exponentiation By Squaring.
  defp _pow(x, n, y \\ 1)
  defp _pow(_x, 0, y), do: y
  defp _pow(x, 1, y), do: x * y
  defp _pow(x, n, y) when Kernel.<(n, 0), do: _pow(1 / x, Kernel.-(n), y)
  defp _pow(x, n, y) when rem(n, 2) == 0, do: _pow(x * x, div(n, 2), y)
  defp _pow(x, n, y), do: _pow(x * x, div((n - 1), 2), x * y)
    


  @doc """
  Converts the given *number* to a Float. As floats do not have arbitrary precision, this operation is generally not reversible.
  """
  def to_float(%Rational{numerator: numerator, denominator: denominator}), do: Kernel./(numerator, denominator)
  def to_float(number), do: :erlang.float(number)



  @doc """
  Check if a number is a rational number.
  Returns false if the number is an integer, float or any other type.

  To check if a float representation will result in a rational number, combine it with the unary plus operation:
  
  ## Examples

      iex>Rational.is_rational?(10)
      false
      iex>Rational.is_rational?("foo")
      false
      iex>Rational.is_rational?(10.0)
      false
      iex>Rational.is_rational?(10.234)
      false
      iex>Rational.is_rational?(10 <|> 3)
      true
      iex>Rational.is_rational?(10 <|> 5)
      false
      iex>Rational.is_rational?(+20.234)
      true
      iex>Rational.is_rational?(+20.0)
      false

  """
  def is_rational?(%Rational{}), do: true
  def is_rational?(_), do: false


  @doc """
  Returns a binstring representation of the Rational number.
  If the denominator is `1`, it will be printed as a normal (integer) number.

  ## Examples

      iex> Rational.to_string 10 <|> 7
      "10 <|> 7"
  """
  def to_string(rational)
  def to_string(%Rational{numerator: numerator, denominator: denominator}) when denominator == 1 do
    "#{numerator}"
  end
  def to_string(%Rational{numerator: numerator, denominator: denominator}) do
    "#{numerator} <|> #{denominator}"
  end

  defimpl String.Chars, for: Rational do
    def to_string(rational) do
      Rational.to_string(rational)    
    end
  end

  defimpl Inspect, for: Rational do
    def inspect(rational, _) do
      Rational.to_string(rational)    
    end
  end


  # Simplifies the Rational to its most basic form.
  # Which might result in an integer.
  # Ensures that a `-` is only kept in the numerator.
  defp simplify(rational)

  defp simplify(%Rational{numerator: numerator, denominator: denominator}) do
    gcdiv = gcd(numerator, denominator)
    new_denominator = Kernel.div(denominator, gcdiv)
    if new_denominator < 0 do
      new_denominator = Kernel.-(new_denominator)
      numerator = Kernel.-(numerator)
    end

    if new_denominator == 1 do
      Kernel.div(numerator, gcdiv)
    else
      %Rational{numerator: Kernel.div(numerator, gcdiv), denominator: new_denominator}
    end
  end

  # Returns an integer if the result is of the form _ <|> 1
  defp remove_denominator_if_integer(rational)
  defp remove_denominator_if_integer(%Rational{numerator: numerator, denominator: 1}), do: numerator
  defp remove_denominator_if_integer(rational), do: rational


  # Calculates the Greatest Common denominator of two numbers.
  defp gcd(a, 0), do: abs(a)
  
  defp gcd(0, b), do: abs(b)
  defp gcd(a, b), do: gcd(b, Kernel.rem(a,b))

  defoverridable @overridden_math_functions # So they can without problem be overridden by other libraries that extend on this one. 
end


