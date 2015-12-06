
module ADP.Fusion.Term.PeekIndex.Type where

import Data.Strict.Tuple

import Data.PrimitiveArray

import ADP.Fusion.Base



data PeekIndex i = PeekIndex

instance Build (PeekIndex i)

instance
  ( Element ls i
  ) => Element (ls :!: PeekIndex i) i where
    data Elm (ls :!: PeekIndex i) i = ElmPeekIndex !(RunningIndex i) !(Elm ls i)
    type Arg (ls :!: PeekIndex i)   = Arg ls :. RunningIndex i
    getArg (ElmPeekIndex i ls)    = getArg ls :. i
    getIdx (ElmPeekIndex i _ )    = i
    {-# Inline getArg #-}
    {-# Inline getIdx #-}

deriving instance (Show i, Show (RunningIndex i), Show (Elm ls i)) => Show (Elm (ls :!: PeekIndex i) i)

type instance TermArg (PeekIndex i) = PeekIndex i

