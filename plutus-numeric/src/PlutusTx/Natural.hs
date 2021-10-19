-- | An on-chain numeric type representing non-negative integers.
module PlutusTx.Natural (
  -- * Types,
  Internal.Natural,
  Internal.Parity (..),

  -- * Quasi-quoter
  QQ.nat,

  -- * Functions
  Internal.parity,
) where

import PlutusTx.Natural.Internal as Internal
import PlutusTx.Natural.QQ as QQ