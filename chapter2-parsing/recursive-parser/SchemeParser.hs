module SchemeParser (LispVal (..), readExpr) where

import Data.Char
import Control.Monad
import Text.ParserCombinators.Parsec hiding (spaces1)
import Numeric
import Data.Array
import Data.Complex
import Data.Ratio

data LispVal = Atom String
                | List [LispVal]
                | DottedList [LispVal] LispVal
                | Vector (Array Int LispVal)
                | Number Integer
                | Float Double
                | Complex  (Complex Double)
                | Rational Rational
                | String String
                | Bool Bool
                | Char Char
                deriving (Eq, Show)

parseExpr :: Parser LispVal
parseExpr =  parseString
          <|> parseVector
          <|> parseAtom
          <|> parseChar
          <|> try parseComplexNumber
          <|> try parseFloat
          <|> try parseRationalNumber
          <|> parseNumber
          <|> parseQuoted
          <|> parseQuasiQuoted
          <|> parseUnQuote
          <|> parseAllTheLists

readExpr :: String -> String
readExpr input = case parse parseExpr "lisp" input of
    Left err ->"No match: " ++ show err
    Right val -> show val

parseVector :: Parser LispVal
parseVector = do string "#("
                 elems <- sepBy parseExpr spaces1
                 char ')'
                 return $ Vector (listArray (0, (length elems)-1) elems)

parseAllTheLists ::Parser LispVal
parseAllTheLists = do  char '(' >> spaces
                       head <- parseExpr `sepEndBy` spaces1
                       do char '.' >> spaces1
                          tail <- parseExpr
                          spaces >> char ')'
                          return $ DottedList head tail
                        <|> (spaces >> char ')' >> (return $ List head))

parseList :: Parser LispVal
parseList = fmap List $ sepBy parseExpr spaces1

parseDottedList :: Parser LispVal
parseDottedList = do
        head <- endBy parseExpr spaces1
        tail <- char '.' >> spaces1 >> parseExpr
        return $ DottedList head tail

parseQuoted :: Parser LispVal
parseQuoted = do
        char '\''
        x <- parseExpr
        return $ List [Atom "quote", x]

parseQuasiQuoted :: Parser LispVal
parseQuasiQuoted = do
   char '`'
   x <- parseExpr
   return $ List [Atom "quasiquote", x]

parseUnQuote :: Parser LispVal
parseUnQuote = do
   char ','
   x <- parseExpr
   return $ List [Atom "unquote", x]

parseComplexNumber :: Parser LispVal
parseComplexNumber = do realPart <- fmap toDouble $ (try parseFloat) <|> readPlainNumber
                        char '+'
                        imaginaryPart <- fmap toDouble $ (try parseFloat) <|> readPlainNumber
                        char 'i'
                        return $ Complex (realPart :+ imaginaryPart)
                            where toDouble (Float x) = x
                                  toDouble (Number x) = fromInteger x :: Double


parseRationalNumber :: Parser LispVal
parseRationalNumber = do numerator <- many digit
                         char '/'
                         denominator <- many digit
                         return $ Rational (read (numerator ++ "%" ++ denominator) :: Rational)

parseFloat :: Parser LispVal
parseFloat = do whole <- many1 digit
                char '.'
                decimal <- many1 digit
                return $ Float (read (whole ++ "." ++ decimal))

parseAtom :: Parser LispVal
parseAtom = do first <- letter <|> symbol
               rest <- many (letter <|> digit <|> symbol)
               let atom = first:rest
               return $ case atom of
                           "#t" -> Bool True
                           "#f" -> Bool False
                           _    -> Atom atom
symbol :: Parser Char
symbol = oneOf "!#$%&|*+-/:<=>?@^_~"

spaces1 :: Parser ()
spaces1 = skipMany1 space

parseChar :: Parser LispVal
parseChar = do string "#\\"
               c <- many1 letter
               return $ case map toLower c of
                   "newline" -> Char '\n'
                   "space" -> Char ' '
                   [x] -> Char x

escapedChar :: Parser Char
escapedChar = char '\\' >> oneOf("\"nrt\\") >>= \c ->
                            return $ case c of
                                    '\\' -> '\\'
                                    'n' -> '\n'
                                    'r' -> '\r'
                                    't' -> '\t'

parseString :: Parser LispVal
parseString = do  char '"'
                  x <- many (noneOf "\"" <|> escapedChar)
                  char '"'
                  return $ String x

parseNumber :: Parser LispVal
parseNumber = readPlainNumber <|> parseRadixNumber

readPlainNumber:: Parser LispVal
readPlainNumber = do
                    d <- many1 digit
                    return $ Number . read $ d

parseRadixNumber :: Parser LispVal
parseRadixNumber = char '#' >>
                    ((char 'd' >> readPlainNumber)
                     <|> (char 'b' >> readBinaryNumber)
                     <|> (char 'o' >> readOctalNumber)
                     <|> (char 'x' >> readHexNumber))

readBinaryNumber = readNumberInBase "01" 2
readOctalNumber = readNumberInBase "01234567" 8
readHexNumber = readNumberInBase "0123456789abcdefABCEDF" 16

readNumberInBase :: String -> Integer -> Parser LispVal
readNumberInBase digits base = do
                    d <- many (oneOf (digits))
                    return $ Number $ toDecimal base d

toDecimal :: Integer -> String -> Integer
toDecimal base s = foldl1 ((+) . (* base)) $ map toNumber s
                    where toNumber  =  (toInteger . digitToInt)

