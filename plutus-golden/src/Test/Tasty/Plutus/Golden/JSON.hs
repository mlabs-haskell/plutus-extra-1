{-# LANGUAGE AllowAmbiguousTypes #-}

module Test.Tasty.Plutus.Golden.JSON (doGoldenJSON) where

import Control.Monad.Extra (ifM)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Reader (ReaderT, asks)
import Data.Aeson (ToJSON (toJSON), Value)
import Data.Aeson.Encode.Pretty (encodePretty)
import Data.ByteString.Lazy qualified as Lazy
import Data.Function (on)
import Data.Kind (Type)
import Data.Maybe (mapMaybe)
import Data.Text qualified as T
import Data.Text.Encoding qualified as Encoding
import Data.Vector qualified as Vector
import System.Directory (
  createDirectoryIfMissing,
  doesFileExist,
  getCurrentDirectory,
 )
import System.FilePath ((<.>), (</>))
import Test.Tasty.Plutus.Generator (Generator (Generator))
import Test.Tasty.Plutus.Golden.Internal (
  Config (
    configGenerator,
    configGoldenPath,
    configRng,
    configSampleSize,
    configSeed,
    configTypeName
  ),
  Sample (
    Sample,
    sampleData,
    sampleSeed
  ),
  SampleError (
    NotJSON,
    NotSample
  ),
  deserializeSample,
  serializeSample,
 )
import Test.Tasty.Providers (Result, testFailed, testPassed)
import Test.Tasty.Runners (resultSuccessful)
import Text.PrettyPrint (
  Doc,
  Style (lineLength),
  int,
  renderStyle,
  style,
  text,
  ($+$),
  (<+>),
 )
import Type.Reflection (
  Typeable,
  tyConModule,
  typeRep,
  typeRepTyCon,
 )
import Prelude hiding (exp)

doGoldenJSON ::
  forall (a :: Type).
  (ToJSON a, Typeable a) =>
  ReaderT (Config a) IO Result
doGoldenJSON = do
  cwd <- liftIO getCurrentDirectory
  goldenPath <- asks configGoldenPath
  let folderPath = cwd </> goldenPath </> "json"
  tyName <- asks configTypeName
  let filePath = folderPath </> sampleFileName @a tyName <.> "json"
  liftIO . createDirectoryIfMissing True $ folderPath
  sample <- genJSONSample
  ifM
    (liftIO . doesFileExist $ filePath)
    (loadAndCompareSamples filePath sample)
    (writeSampleToFile filePath sample)

-- Helpers

-- We can easily have multiple types with the same name in the same package. To
-- avoid these clashing, we use fully qualified names, but with . replaced with
-- -, to avoid triggering bad filename behaviour.
sampleFileName :: forall (a :: Type). (Typeable a) => String -> FilePath
sampleFileName tyName = mapMaybe go $ moduleName <> "." <> tyName
  where
    go :: Char -> Maybe Char
    go =
      pure . \case
        '.' -> '-'
        c -> c
    moduleName :: String
    moduleName = tyConModule . typeRepTyCon $ typeRep @a

genJSONSample ::
  forall (a :: Type).
  (ToJSON a) =>
  ReaderT (Config a) IO (Sample Value)
genJSONSample = do
  rng <- asks configRng
  Generator f <- asks configGenerator
  sampleSize <- asks configSampleSize
  seed <- asks configSeed
  Sample seed <$> Vector.replicateM sampleSize (toJSON <$> f rng)

loadAndCompareSamples ::
  forall (a :: Type).
  FilePath ->
  Sample Value ->
  ReaderT (Config a) IO Result
loadAndCompareSamples fp sample = do
  result <- liftIO . deserializeSample pure $ fp
  pure $ case result of
    Left err -> testFailed . sampleError $ err
    Right expected -> compareSamples fp expected sample
  where
    sampleError :: SampleError -> String
    sampleError err = renderStyle ourStyle $ case err of
      NotJSON err' ->
        "Could not parse sample file as JSON."
          $+$ ""
          $+$ dumpFileLocation fp
          $+$ ""
          $+$ "Parse error"
          $+$ ""
          $+$ text err'
      NotSample err' ->
        "Given file is not a valid sample file."
          $+$ ""
          $+$ dumpFileLocation fp
          $+$ ""
          $+$ "Parse error"
          $+$ ""
          $+$ text err'

compareSamples ::
  FilePath ->
  Sample Value ->
  Sample Value ->
  Result
compareSamples fp expected actual =
  case (compare `on` sampleSeed) expected actual of
    EQ -> case (compare `on` (Vector.length . sampleData)) expected actual of
      EQ ->
        let expVec = sampleData expected
            actVec = sampleData actual
         in Vector.ifoldl' go (testPassed "") . Vector.zip expVec $ actVec
      _ -> testFailed mismatchedSampleCounts
    _ -> testFailed mismatchedSeeds
  where
    go ::
      Result ->
      Int ->
      (Value, Value) ->
      Result
    go acc ix (ex, act)
      | resultSuccessful acc = case compare ex act of
        EQ -> acc
        _ -> testFailed . mismatchedSample ix ex $ act
      | otherwise = acc
    mismatchedSampleCounts :: String
    mismatchedSampleCounts =
      let expectedLen = Vector.length . sampleData $ expected
          actualLen = Vector.length . sampleData $ actual
       in renderStyle ourStyle $
            "Unexpected number of samples"
              $+$ ""
              $+$ dumpFileLocation fp
              $+$ "Expected:" <+> int expectedLen
              $+$ "Actual:" <+> int actualLen
    mismatchedSeeds :: String
    mismatchedSeeds =
      let expectedSeed = sampleSeed expected
          actualSeed = sampleSeed actual
       in renderStyle ourStyle $
            "Seeds do not match"
              $+$ ""
              $+$ dumpFileLocation fp
              $+$ "Expected:" <+> int expectedSeed
              $+$ "Actual:" <+> int actualSeed
    mismatchedSample ::
      Int ->
      Value ->
      Value ->
      String
    mismatchedSample ix exp act =
      renderStyle ourStyle $
        "Sample" <+> int ix <+> "does not match."
          $+$ ""
          $+$ dumpFileLocation fp
          $+$ ""
          $+$ "Expected"
          $+$ ""
          $+$ renderJSON exp
          $+$ ""
          $+$ "Actual"
          $+$ ""
          $+$ renderJSON act

dumpFileLocation :: FilePath -> Doc
dumpFileLocation fp = "Sample file location:" <+> text fp

writeSampleToFile ::
  FilePath ->
  Sample Value ->
  ReaderT (Config a) IO Result
writeSampleToFile fp sample = do
  liftIO . serializeSample toJSON fp $ sample
  pure . testPassed . renderStyle ourStyle $
    "Generated:" <+> text fp

ourStyle :: Style
ourStyle = style {lineLength = 80}

renderJSON :: Value -> Doc
renderJSON =
  text
    . T.unpack
    . Encoding.decodeUtf8
    . Lazy.toStrict
    . encodePretty