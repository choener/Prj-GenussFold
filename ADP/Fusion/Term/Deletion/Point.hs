
module ADP.Fusion.Term.Deletion.Point where

import           Data.Proxy
import           Data.Strict.Tuple
import qualified Data.Vector.Fusion.Stream.Monadic as S

import           Data.PrimitiveArray

import           ADP.Fusion.Base
import           ADP.Fusion.Term.Deletion.Type



instance
  ( TmkCtx1 m ls Deletion (PointL i)
  ) => MkStream m (ls :!: Deletion) (PointL i) where
  mkStream (ls :!: Deletion) sv us is
    = S.map (\(ss,ee,ii,oo) -> ElmDeletion ii oo ss)
    . addTermStream1 Deletion sv us is
    $ mkStream ls (termStaticVar Deletion sv is) us (termStreamIndex Deletion sv is)
  {-# Inline mkStream #-}



instance
  ( TstCtx1 m ts a is (PointL I)
  ) => TermStream m (TermSymbol ts Deletion) a (is:.PointL I) where
  termStream (ts:|Deletion) (cs:.IStatic d) (us:.PointL u) (is:.PointL i)
    = S.map (\(TState s a b ii oo ee) -> TState s a b (ii:.PointL i) (oo:.PointL 0) (ee:.()))
    . termStream ts cs us is
  {-# Inline termStream #-}

instance
  ( TstCtx1 m ts a is (PointL O)
  ) => TermStream m (TermSymbol ts Deletion) a (is:.PointL O) where
  termStream (ts:|Deletion) (cs:.OStatic d) (us:.PointL u) (is:.PointL i)
    = S.map (\(TState s a b ii oo ee) ->
                let i' = getIndex a (Proxy :: Proxy (is:.PointL O))
                    o' = getIndex b (Proxy :: Proxy (is:.PointL O))
                in  TState s a b (ii:.i') (oo:.o') (ee:.()))
    . termStream ts cs us is
  {-# Inline termStream #-}



instance TermStaticVar Deletion (PointL I) where
  termStaticVar _ sv _ = sv
  termStreamIndex _ _ (PointL j) = PointL j
  {-# Inline [0] termStaticVar #-}
  {-# Inline [0] termStreamIndex #-}

instance TermStaticVar Deletion (PointL O) where
  termStaticVar   _ (OStatic d) _ = OStatic d
  termStreamIndex _ _           j = j
  {-# Inline [0] termStaticVar #-}
  {-# Inline [0] termStreamIndex #-}

