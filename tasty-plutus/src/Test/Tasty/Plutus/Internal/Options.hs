module Test.Tasty.Plutus.Internal.Options (
  PropertyTestCount (..),
  PropertyMaxSize (..),
  DumpPath (..),
  DumpPlutusIR (..),
  DumpPlutusTypedCore (..),
  DumpPlutusCore (..),
) where

import Data.Coerce (Coercible, coerce)
import Data.Kind (Type)
import Data.Tagged (Tagged (Tagged))
import Test.Tasty.Options (
  IsOption (
    defaultValue,
    optionHelp,
    optionName,
    parseValue,
    showDefaultValue
  ),
 )
import Text.Read (readMaybe)

{- | The number of property tests to run.

 This defaults to 1000. When passing this via CLI, use a positive integer
 only, and ensure that it's in bounds for 'Int'.

 @since 3.1
-}
newtype PropertyTestCount = PropertyTestCount Int
  deriving stock
    ( -- | @since 3.1
      Show
    )

-- | @since 3.1
instance IsOption PropertyTestCount where
  defaultValue = PropertyTestCount 1000
  parseValue s = PropertyTestCount <$> (readMaybe s >>= go)
    where
      go :: Int -> Maybe Int
      go i = case signum i of
        (-1) -> Nothing
        0 -> Nothing
        _ -> Just i
  optionName = Tagged "property-test-count"
  optionHelp = Tagged "Number of property tests to run."
  showDefaultValue (PropertyTestCount i) = Just . show $ i

{- | The maximum size given to generators for properties.

 This defaults to 100 (same as QuickCheck). When passing this via CLI, use a
 positive integer only, and ensure that it's in bounds for 'Int'.

 @since 3.1
-}
newtype PropertyMaxSize = PropertyMaxSize Int
  deriving stock
    ( -- | @since 3.1
      Show
    )

-- | @since 3.1
instance IsOption PropertyMaxSize where
  defaultValue = PropertyMaxSize 100
  parseValue s = PropertyMaxSize <$> (readMaybe s >>= go)
    where
      go :: Int -> Maybe Int
      go i = case signum i of
        (-1) -> Nothing
        0 -> Nothing
        _ -> Just i
  optionName = Tagged "property-max-size"
  optionHelp = Tagged "Maximum size for generators used for property tests."
  showDefaultValue (PropertyMaxSize i) = Just . show $ i

data DumpPath = DumpPath FilePath | NoDumpPath
  deriving stock (Show, Eq)

showDumpPath :: forall (v :: Type). Coercible v DumpPath => v -> Maybe String
showDumpPath opt = case coerce opt of
  DumpPath path -> Just path
  NoDumpPath -> Just "<doesn't dump>"

newtype DumpPlutusIR = DumpPlutusIR DumpPath
  deriving stock (Show, Eq)

instance IsOption DumpPlutusIR where
  defaultValue = DumpPlutusIR NoDumpPath
  parseValue s = Just $ DumpPlutusIR $ DumpPath s
  optionName = Tagged "dump-plutus-ir"
  optionHelp = Tagged "Dump Plutus IR for tested scripts into the given path."
  showDefaultValue = showDumpPath

newtype DumpPlutusTypedCore = DumpPlutusTypedCore DumpPath
  deriving stock (Show, Eq)

instance IsOption DumpPlutusTypedCore where
  defaultValue = DumpPlutusTypedCore NoDumpPath
  parseValue s = Just $ DumpPlutusTypedCore $ DumpPath s
  optionName = Tagged "dump-plutus-typed-core"
  optionHelp =
    Tagged "Dump Plutus Typed Core for tested scripts into the given path."
  showDefaultValue = showDumpPath

newtype DumpPlutusCore = DumpPlutusCore DumpPath
  deriving stock (Show, Eq)

instance IsOption DumpPlutusCore where
  defaultValue = DumpPlutusCore NoDumpPath
  parseValue s = Just $ DumpPlutusCore $ DumpPath s
  optionName = Tagged "dump-plutus-core"
  optionHelp =
    Tagged "Dump Plutus Untyped Core for tested scripts into the given path."
  showDefaultValue = showDumpPath
