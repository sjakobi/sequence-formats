{-# LANGUAGE OverloadedStrings #-}

-- |This module contains helper functions for file parsing.

module SequenceFormats.Utils (liftParsingErrors,
                              consumeProducer,
                              FormatException(..),
                              Chrom(..)) where

import Control.Error (readErr)
import Control.Exception (Exception)
import Control.Monad.Catch (MonadThrow, throwM)
import Control.Monad.Trans.Class (lift)
import qualified Data.Text as T
import qualified Data.Attoparsec.Text as A
import Pipes (Producer, next)
import Pipes.Attoparsec (ParsingError(..), parsed)

-- |A wrapper datatype for Chromosome names.
newtype Chrom = Chrom {unChrom :: T.Text} deriving (Eq)

-- |Show instance for Chrom
instance Show Chrom where
    show (Chrom c) = show c

-- |Ord instance for Chrom
instance Ord Chrom where
    compare (Chrom c1) (Chrom c2) = 
        let c1' = if T.take 3 c1 == "chr" then T.drop 3 c1 else c1
            c2' = if T.take 3 c2 == "chr" then T.drop 3 c2 else c2
        in  case (,) <$> readChrom c1' <*> readChrom c2' of
                Left e -> error e
                Right (cn1, cn2) -> cn1 `compare` cn2

readChrom :: T.Text -> Either String Int
readChrom c = readErr ("cannot parse chromosome " ++ show c) . T.unpack $ c

-- |An exception type for parsing BioInformatic file formats.
data FormatException = FormatException T.Text
    deriving Show

instance Exception FormatException

-- |A function to help with reporting parsing errors to stderr. Returns a clean Producer over the 
-- parsed datatype.
liftParsingErrors :: (MonadThrow m) =>
    Either (ParsingError, Producer T.Text m r) () -> Producer a m ()
liftParsingErrors res = case res of
    Left (ParsingError cont msg, restProd) -> do
        x <- lift $ next restProd
        case x of
            Right (chunk, _) -> do
                let msg' = msg ++ " Error occurred while trying to parse this chunk: " ++ show chunk
                throwM (ParsingError cont msg')
            Left _ -> error "should not happen"
    Right () -> return ()

-- |A helper function to parse a text producer, properly reporting all errors to stderr.
consumeProducer :: (MonadThrow m) => A.Parser a -> Producer T.Text m () -> Producer a m ()
consumeProducer parser prod = parsed parser prod >>= liftParsingErrors
