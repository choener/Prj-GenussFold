
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE RankNTypes #-}

{-# LANGUAGE MagicHash #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE PatternGuards #-}

-- | Tables in ADPfusion memoize results of parses. In the forward phase, table
-- cells are filled by a table-filling method from @Data.PrimitiveArray@. In
-- the backtracking phase, grammar rules are associated with tables to provide
-- efficient backtracking.
--
-- TODO multi-dim tables with 'OnlyZero' need a static check!
--
-- TODO PointL , PointR need sanity checks for boundaries
--
-- TODO the sanity checks are acutally a VERY BIG TODO since currently we do
-- not protect against stupidity at all!
--
-- TODO have boxed tables for top-down parsing.
--
-- TODO combine forward and backward phases to simplify the external interface
-- to the programmer.
--
-- TODO include the notion of @interfaces@ into tables. With Outside
-- grammars coming up now, we need this.

module ADP.Fusion.Table.Array
--  ( MTbl      (..)
--  , BtTbl     (..)
  ( ITbl      (..)
--  , Backtrack (..)
  , ToBT (..)
  ) where

import           Control.Exception(assert)
import           Control.Monad.Primitive (PrimMonad)
import           Data.Strict.Tuple hiding (uncurry)
import           Data.Vector.Fusion.Stream.Size (Size(Unknown))
import qualified Data.Vector as V
import qualified Data.Vector.Fusion.Stream.Monadic as S
import qualified Data.Vector.Generic as VG
import qualified Data.Vector.Storable as VS
import qualified Data.Vector.Unboxed as VU
import           GHC.Exts

import           Data.PrimitiveArray (Z(..), (:.)(..), Subword(..), subword, PointL(..), pointL, PointR(..), pointR,topmostIndex, Outside(..))
import qualified Data.PrimitiveArray as PA

import           ADP.Fusion.Classes
import           ADP.Fusion.Multi.Classes
import           ADP.Fusion.Table.Axiom
import           ADP.Fusion.Table.Backtrack
import           ADP.Fusion.Table.Indices

import           Debug.Trace



-- ** Mutable fill-phase tables.

-- | Immutable table.

data ITbl m arr i x where
  ITbl :: { iTblConstraint :: !(TblConstraint i)
          , iTblArray      :: !(arr i x)
          , iTblFun        :: !(i -> i -> m x)
          } -> ITbl m arr i x

-- | The backtracking version.

instance ToBT (ITbl mF arr i x) mF mB r where
  --data BT (ITbl mF arr i x) mF mB i r = BtITbl (ITbl mF arr i x) (forall a . mF a -> mB a)  (i -> mB (S.Stream mB r))
  data BT (ITbl mF arr i x) mF mB r = BtITbl !(TblConstraint i) !(arr i x) (i -> i -> mB (S.Stream mB r))
  type BtIx (ITbl mF arr i x) = i
  toBT (ITbl c arr _) _ bt = BtITbl c arr bt
  {-# INLINE toBT #-}


instance Build (ITbl m arr i x)


instance Element ls i => Element (ls :!: ITbl m arr j x) i where
  data Elm (ls :!: ITbl m arr j x) i = ElmITbl !x !i !(Elm ls i)
  type Arg (ls :!: ITbl m arr j x)   = Arg ls :. x
  getArg (ElmITbl x _ ls) = getArg ls :. x
  getIdx (ElmITbl _ i _ ) = i
  {-# INLINE getArg #-}
  {-# INLINE getIdx #-}

instance Element ls i => Element (ls :!: (BT (ITbl mF arr i x) mF mB r)) i where
  data Elm (ls :!: (BT (ITbl mF arr i x) mF mB r)) i = ElmBtITbl' !x !(mB (S.Stream mB r)) !i !(Elm ls i)
  type Arg (ls :!: (BT (ITbl mF arr i x) mF mB r))   = Arg ls :. (x, mB (S.Stream mB r))
  getArg (ElmBtITbl' x s _ ls) = getArg ls :. (x,s)
  getIdx (ElmBtITbl' _ _ i _ ) = i
  {-# INLINE getArg #-}
  {-# INLINE getIdx #-}




instance ModifyConstraint (ITbl m arr Subword x) where
  toNonEmpty (ITbl _ arr f) = ITbl NonEmpty arr f
  toEmpty    (ITbl _ arr f) = ITbl EmptyOk  arr f
  {-# INLINE toNonEmpty #-}
  {-# INLINE toEmpty #-}

instance ModifyConstraint (BT (ITbl mF arr Subword x) mF mB r) where
  toNonEmpty (BtITbl _ arr bt) = BtITbl NonEmpty arr bt
  toEmpty    (BtITbl _ arr bt) = BtITbl EmptyOk  arr bt
  {-# INLINE toNonEmpty #-}
  {-# INLINE toEmpty #-}

instance
  ( Monad m
  , Element ls PointL
  , PA.PrimArrayOps arr PointL x
  , MkStream m ls PointL
  ) => MkStream m (ls :!: ITbl m arr PointL x) PointL where
  mkStream (ls :!: ITbl c t _) Static lu@(PointL (l:.u)) (PointL (i:.j))
  -- TODO sure about these assertions below? they should be ok, given that
  -- we are in a linear grammar context ...
    = let ms = minSize c in seq ms $ seq t $
    S.map (\s -> let PointL (_:.k) = getIdx s
                 in  ElmITbl (t PA.! pointL k j) (pointL k j) s)
    $ mkStream ls (Variable Check Nothing) lu (pointL i $ j - ms)
--  mkStream _ _ _ _ = error "mkStream / ITbl / PointL not implemented"
  {-# INLINE mkStream #-}

instance
  ( Monad mB
  , Element ls PointL
  , PA.PrimArrayOps arr PointL x
  , MkStream mB ls PointL
  ) => MkStream mB (ls :!: BT (ITbl mF arr PointL x) mF mB r) PointL where
  mkStream (ls :!: BtITbl c arr bt) Static lu (PointL (i:.j))
    = let ms = minSize c in ms `seq`
    S.map (\s -> let PointL (h:.k) = getIdx s
                     ix            = pointL k j
                     d             = arr PA.! ix
                 in ElmBtITbl' d (bt lu ix) ix s)
    $ mkStream ls (Variable Check Nothing) lu (pointL i $ j - ms)
--  mkStream _ _ _ _ = error "mkStream / BT ITbl / PointL not implemented"
  {-# INLINE mkStream #-}

instance
  ( Monad m
  , Element ls (Outside PointL)
  , PA.PrimArrayOps arr (Outside PointL) x
  , MkStream m ls (Outside PointL)
  ) => MkStream m (ls :!: ITbl m arr (Outside PointL) x) (Outside PointL) where
  mkStream (ls :!: ITbl c t _) Static lu (O (PointL (i:.j)))
    = let ms = minSize c in seq ms $ seq t $
    S.mapM (\s -> let O (PointL (h:.k)) = getIdx s
                  in  return $ ElmITbl (t PA.! O (pointL k j)) (O $ pointL k j) s)
    $ mkStream ls (Variable Check Nothing) lu (O . pointL i $ j + ms)
--  mkStream _ _ _ _ = error "mkStream / ITbl / Outside PointL not implemented"
  {-# INLINE mkStream #-}

instance
  ( Monad mB
  , Element ls (Outside PointL)
  , PA.PrimArrayOps arr (Outside PointL) x
  , MkStream mB ls (Outside PointL)
  ) => MkStream mB (ls :!: BT (ITbl mF arr (Outside PointL) x) mF mB r) (Outside PointL) where
  mkStream (ls :!: BtITbl c arr bt) Static lu (O (PointL (i:.j)))
    = let ms = minSize c in ms `seq`
    S.map (\s -> let O (PointL (h:.k)) = getIdx s
                     ix                = O $ pointL k j
                     d                 = arr PA.! ix
                 in ElmBtITbl' d (bt lu ix) ix s)
    $ mkStream ls (Variable Check Nothing) lu (O . pointL i $ j + ms)
--  mkStream _ _ _ _ = error "mkStream / BT ITbl / Outside PointL not implemented"
  {-# INLINE mkStream #-}

-- | TODO As soon as we don't do static checking on @EmptyOk/NonEmpty@
-- anymore, this works! If we check @c@, we immediately have fusion
-- breaking down!

instance
  ( Monad m
  , Element ls Subword
  , PA.PrimArrayOps arr Subword x
  , MkStream m ls Subword
  ) => MkStream m (ls :!: ITbl m arr Subword x) Subword where
  mkStream (ls :!: ITbl c t _) Static lu (Subword (i:.j))
    = let ms = minSize c in ms `seq`
      S.mapM (\s -> let Subword (_:.l) = getIdx s
                    in  return $ ElmITbl (t PA.! subword l j) (subword l j) s)
    $ mkStream ls (Variable Check Nothing) lu (subword i $ j - ms) -- - minSize c)
  mkStream (ls :!: ITbl c t _) (Variable _ Nothing) lu (Subword (i:.j))
    = let ms = minSize c
          {- data PBI a = PBI !a !(Int#)
          mk s = let (Subword (_:.l)) = getIdx s ; !(I# jlm) = j-l-ms in return $ PBI s jlm
          step !(PBI s z) | 1# <- z >=# 0# = do let (Subword (_:.k)) = getIdx s
                                                return $ S.Yield (ElmITbl (t PA.! subword k (j-(I# z))) (subword k $ j-(I# z)) s) (PBI s (z -# 1#))
                          | otherwise = return S.Done
          -}
          {-
          mk s = let (Subword (_:.l)) = getIdx s in return (s :. j - l - ms)
          step (s:.z) | 1# <- z' >=# 0# = do let (Subword (_:.k)) = getIdx s
                                             return $ S.Yield (ElmITbl (t PA.! subword k (j-z)) (subword k $ j-z) s) (s:.z-1)
                      | otherwise = return S.Done
                      where !(I# z') = z
          -}
          mk s = let (Subword (_:.l)) = getIdx s in return (s :. j - l - ms)
          step (s:.z) | z>=0 = do let (Subword (_:.k)) = getIdx s
                                  return $ S.Yield (ElmITbl (t PA.! subword k (j-z)) (subword k $ j-z) s) (s:.z-1)
                      | otherwise = return S.Done
          {-# INLINE [1] mk #-}
          {-# INLINE [1] step #-}
      in ms `seq` S.flatten mk step Unknown $ mkStream ls (Variable NoCheck Nothing) lu (subword i j)
  {-# INLINE mkStream #-}

instance
  ( Monad mB
  , Element ls Subword
  , MkStream mB ls Subword
  , PA.PrimArrayOps arr Subword x
  ) => MkStream mB (ls :!: BT (ITbl mF arr Subword x) mF mB r) Subword where
  mkStream (ls :!: BtITbl c arr bt)  Static lu (Subword (i:.j))
    = let ms = minSize c in ms `seq`
      S.map (\s -> let (Subword (_:.l)) = getIdx s
                       ix               = subword l j
                       d                = arr PA.! ix
                   in  ElmBtITbl' d (bt lu ix) ix s)
      $ mkStream ls (Variable Check Nothing) lu (subword i $ j - ms)
  mkStream (ls :!: BtITbl c arr bt) (Variable _ Nothing) lu (Subword (i:.j))
    = let ms = minSize c
          mk s = let (Subword (_:.l)) = getIdx s in return (s:.j-l-ms)
          step (s:.z)
            | z>=0      = do let (Subword (_:.k)) = getIdx s
                                 ix               = subword k (j-z)
                                 d                = arr PA.! ix
                             return $ S.Yield (ElmBtITbl' d (bt lu ix) ix s) (s:.z-1)
            | otherwise = return $ S.Done
          {-# INLINE [1] mk   #-}
          {-# INLINE [1] step #-}
      in  ms `seq` S.flatten mk step Unknown $ mkStream ls (Variable NoCheck Nothing) lu (subword i j)
  {-# INLINE mkStream #-}

instance
  ( Monad m
  , Element ls (Outside Subword)
  , PA.PrimArrayOps arr Subword x
  , MkStream m ls (Outside Subword)
  ) => MkStream m (ls :!: ITbl m arr Subword x) (Outside Subword) where
  mkStream (ls :!: ITbl c t _) Static lu (O (Subword (i:.j)))
    = let ms = minSize c in ms `seq`
      S.mapM (\s -> let (O (Subword (_:.l))) = getIdx s
                    in  return $ ElmITbl (t PA.! (subword l j)) (O $ subword l j) s)
    $ mkStream ls (Variable Check Nothing) lu (O $ subword i $ j - ms) -- - minSize c)
  mkStream (ls :!: ITbl c t _) (Variable _ Nothing) lu (O (Subword (i:.j)))
    = let ms = minSize c
          mk s = let (O( Subword (_:.l))) = getIdx s in return (s :. j - l - ms)
          step (s:.z) | z>=0 = do let (O (Subword (_:.k))) = getIdx s
                                  return $ S.Yield (ElmITbl (t PA.! (subword k (j-z))) (O . subword k $ j-z) s) (s:.z-1)
                      | otherwise = return S.Done
          {-# INLINE [1] mk #-}
          {-# INLINE [1] step #-}
      in ms `seq` S.flatten mk step Unknown $ mkStream ls (Variable NoCheck Nothing) lu (O $ subword i j)
  {-# INLINE mkStream #-}

instance
  ( Monad m
  , Element ls (Outside Subword)
  , PA.PrimArrayOps arr (Outside Subword) x
  , MkStream m ls (Outside Subword)
  ) => MkStream m (ls :!: ITbl m arr (Outside Subword) x) (Outside Subword) where
  mkStream (ls :!: ITbl c t _) Static lu (O (Subword (i:.j)))
    = let ms = minSize c in ms `seq`
      S.mapM (\s -> let (O (Subword (_:.l))) = getIdx s
                    in  return $ ElmITbl (t PA.! (O $ subword l j)) (O $ subword l j) s)
    $ mkStream ls (Variable Check Nothing) lu (O $ subword i $ j - ms) -- - minSize c)
  mkStream (ls :!: ITbl c t _) (Variable _ Nothing) lu (O (Subword (i:.j)))
    = let ms = minSize c
          mk s = let (O( Subword (_:.l))) = getIdx s in return (s :. j - l - ms)
          step (s:.z) | z>=0 = do let (O (Subword (_:.k))) = getIdx s
                                  return $ S.Yield (ElmITbl (t PA.! (O $ subword k (j-z))) (O . subword k $ j-z) s) (s:.z-1)
                      | otherwise = return S.Done
          {-# INLINE [1] mk #-}
          {-# INLINE [1] step #-}
      in ms `seq` S.flatten mk step Unknown $ mkStream ls (Variable NoCheck Nothing) lu (O $ subword i j)
  {-# INLINE mkStream #-}



instance
  ( Monad m
  , Element ls (is:.i)
  , TableStaticVar (is:.i)
  , TableIndices (is:.i)
  , MkStream m ls (is:.i)
  , PA.PrimArrayOps arr (is:.i) x
  ) => MkStream m (ls :!: ITbl m arr (is:.i) x) (is:.i) where
  mkStream (ls :!: ITbl c t _) vs lu is
    = S.map (\(Tr s _ i) -> ElmITbl (t PA.! i) i s)
    . tableIndices c vs is
    . S.map (\s -> Tr s Z (getIdx s))
    $ mkStream ls (tableStaticVar vs is) lu (tableStreamIndex c vs is)
  {-# INLINE mkStream #-}

instance
  ( Monad mB
  , Element ls (is:.i)
  , TableStaticVar (is:.i)
  , TableIndices (is:.i)
  , MkStream mB ls (is:.i)
  , PA.PrimArrayOps arr (is:.i) x
  ) => MkStream mB (ls :!: BT (ITbl mF arr (is:.i) x) mF mB r) (is:.i) where
  mkStream (ls :!: BtITbl c arr bt) vs lu is
    = S.map (\(Tr s _ i) -> ElmBtITbl' (arr PA.! i) (bt lu i) i s)
    . tableIndices c vs is
    . S.map (\s -> Tr s Z (getIdx s))
    $ mkStream ls (tableStaticVar vs is) lu (tableStreamIndex c vs is)
  {-# INLINE mkStream #-}



-- * Axiom for backtracking

instance (PA.ExtShape i, PA.PrimArrayOps arr i x) => Axiom (BT (ITbl mF arr i x) mF mB r) where
  type S (BT (ITbl mF arr i x) mF mB r) = mB (S.Stream mB r)
  axiom (BtITbl c arr bt) = bt (error "missing bounds") . uncurry topmostIndex $ PA.bounds arr
  {-# INLINE axiom #-}

