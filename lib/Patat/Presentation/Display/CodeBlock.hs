--------------------------------------------------------------------------------
-- | Displaying code blocks, optionally with syntax highlighting.
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
module Patat.Presentation.Display.CodeBlock
    ( prettyCodeBlock
    ) where


--------------------------------------------------------------------------------
import           Data.Maybe                       (mapMaybe)
import qualified Data.Text                        as T
import           Patat.Presentation.Display.Table (themed)
import qualified Patat.PrettyPrint                as PP
import           Patat.Theme
import           Prelude
import qualified Skylighting                      as Skylighting


--------------------------------------------------------------------------------
highlight :: [T.Text] -> T.Text -> [Skylighting.SourceLine]
highlight classes rawCodeBlock = case mapMaybe getSyntax classes of
    []        -> zeroHighlight rawCodeBlock
    (syn : _) ->
        case Skylighting.tokenize config syn rawCodeBlock of
            Left  _  -> zeroHighlight rawCodeBlock
            Right sl -> sl
  where
    getSyntax :: T.Text -> Maybe Skylighting.Syntax
    getSyntax c = Skylighting.lookupSyntax c syntaxMap

    config :: Skylighting.TokenizerConfig
    config = Skylighting.TokenizerConfig
        { Skylighting.syntaxMap  = syntaxMap
        , Skylighting.traceOutput = False
        }

    syntaxMap :: Skylighting.SyntaxMap
    syntaxMap = Skylighting.defaultSyntaxMap


--------------------------------------------------------------------------------
-- | This does fake highlighting, everything becomes a normal token.  That makes
-- things a bit easier, since we only need to deal with one cases in the
-- renderer.
zeroHighlight :: T.Text -> [Skylighting.SourceLine]
zeroHighlight txt =
    [[(Skylighting.NormalTok, line)] | line <- T.lines txt]


--------------------------------------------------------------------------------
prettyCodeBlock :: Theme -> [T.Text] -> T.Text -> PP.Doc
prettyCodeBlock theme@Theme {..} classes rawCodeBlock =
    PP.vcat (map blockified sourceLines) <>
    PP.hardline
  where
    sourceLines :: [Skylighting.SourceLine]
    sourceLines =
        [[]] ++ highlight classes rawCodeBlock ++ [[]]

    prettySourceLine :: Skylighting.SourceLine -> PP.Doc
    prettySourceLine = mconcat . map prettyToken

    prettyToken :: Skylighting.Token -> PP.Doc
    prettyToken (tokenType, str) =
        themed (syntaxHighlight theme tokenType) (PP.string $ T.unpack str)

    sourceLineLength :: Skylighting.SourceLine -> Int
    sourceLineLength line = sum [T.length str | (_, str) <- line]

    blockWidth :: Int
    blockWidth = foldr max 0 (map sourceLineLength sourceLines)

    blockified :: Skylighting.SourceLine -> PP.Doc
    blockified line =
        let len    = sourceLineLength line
            indent = PP.NotTrimmable "   " in
        PP.indent indent indent $
        themed themeCodeBlock $
            " " <>
            prettySourceLine line <>
            PP.string (replicate (blockWidth - len) ' ') <> " "
