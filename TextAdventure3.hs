module TextAdventure where

import Control.Monad (mapM_)
import Data.Char (toLower)
import Data.List (intercalate)
import qualified Data.Map as Map
import System.IO

import StringFormat

data Adventure = End
               | Do Action Adventure
               | Prompt String Switch

type Action = Options -> IO ()
type Switch = Map.Map String Adventure

data Options = Options { getPromptChars :: String
                       , getTextWidth :: Int
                       , getLineChar :: Char
                       } deriving (Show, Read, Eq)

-- Example usage.
-- ---------------------------------------------------------------------------

main = run myOpts myAdventure

-- Options:

myOpts :: Options
myOpts = Options { getPromptChars = ">> "
                 , getTextWidth = 78
                 , getLineChar = '-'
                 }

-- The adventure:

myAdventure :: Adventure
myAdventure =
    Do intro $
        Prompt "Which direction will you take?" $
            Map.fromList [("left", Do goLeft End), ("right", Do goRight End)]

intro opts = do
    printLines ["You've decided to set out on an adventure."
                ,"You've left your house and taken the path to a crossroads."]

    name <- prompt opts "What is your name?"
    
    printWrap opts ("Hello, %! Your adventure begins..." -%- [name])
    pause

    hr opts

goLeft opts = printWrap opts "You went left!"
goRight opts = printWrap opts "You went right!"

-- Control flow.
-- ---------------------------------------------------------------------------

-- Run an Adventure.
run :: Options -> Adventure -> IO ()
run opts End = printWrap opts "Game over!"
run opts (Do action adventure) = action opts >> run opts adventure
run opts this@(Prompt msg switch) = do
    let switch' = Map.mapKeys normalize switch

    choice <- cmdPrompt opts (Map.keys switch') msg
    case Map.lookup choice switch' of
      Nothing        -> retry (run opts this)
      Just adventure -> run opts adventure

-- Same as prompt, but also takes a list of possible choices and
-- prints them, normalizing the input (see `normalize`).
cmdPrompt :: Options -> [String] -> String -> IO String
cmdPrompt (Options promptStr width _) choices msg = do putStr str
                                                       choice <- getLine
                                                       blankLine
                                                       return $ normalize choice

   where str = wordWrap width msg ++ ('\n':choicesStr) ++ (' ':promptStr)
         choicesStr = "(" ++ intercalate ", " choices ++ ")" 

-- Print something then prompt for input. 
prompt :: Options -> String -> IO String
prompt (Options promptStr width _) message = do putStr str
                                                answer <- fmap strip getLine
                                                blankLine
                                                return answer
    where str = wordWrap width message ++ ('\n':promptStr)


-- Print a "try again" message and execute a given IO action.
retry :: IO () -> IO ()
retry action = putStrLn "Invalid input. Please try again." >> blankLine >> action

-- Pause execution and wait for a keypress to continue.
pause :: IO ()
pause = putStr "<Press any key to continue...>" >> getChar >> return ()

-- Output.
-- ---------------------------------------------------------------------------

-- Print a blank line.
blankLine :: IO ()
blankLine = putChar '\n'

-- Print a horizontal rule.
hr :: Options -> IO ()
hr (Options _ width char) = putStrLn (replicate width char) >> blankLine

-- Print a list of Strings line by line.
printLines :: [String] -> IO ()
printLines xs = mapM_ putStrLn xs >> blankLine

-- Print a String, wrapping its text to the given width.
printWrap :: Options -> String -> IO ()
printWrap opts str = putStrLn (wordWrap (getTextWidth opts) str) >> blankLine

-- String manipulation helpers.
-- ---------------------------------------------------------------------------

-- Remove leading and trailing whitespace from a String.
strip :: String -> String
strip = reverse . dropWhile isWhitespace . reverse . dropWhile isWhitespace
    where isWhitespace = (`elem` [' ', '\t', '\n', '\r'])

-- Strip leading and trailing whitespace and make everything lowercase.
normalize :: String -> String
normalize = map toLower . strip

-- Wrap a String to fit the given width, adding line breaks as necessary.
-- This removes all pre-existing line breaks.
wordWrap :: Int -> String -> String
wordWrap width str
  | length str' <= width = str'
  | otherwise = take width str' ++ "\n" ++ drop width str'
  where str' = filter notLineBreak str
        notLineBreak = not . (`elem` "\n\r")