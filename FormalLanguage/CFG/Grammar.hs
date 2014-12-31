
{-# LANGUAGE TemplateHaskell #-}

-- | The basic data types for formal languages up to and including context-free
-- grammars.
--
-- TODO we shall have to extend the system for multi-tape grammars to allow
-- combined terminal/non-terminal systems. This will basically mean dealing
-- with context-sensitive grammars, at which we can just fully generalize
-- everything.
--
-- TODO we need a general system to generate fresh variable names of varying
-- dimension. This is very much desired for certain operations (especially on
-- products).
--
-- BIGTODO @E _@ are actually the "None" thing in ADPfusion; while normal
-- epsilons are just terminals.

module FormalLanguage.CFG.Grammar where

import           Control.Lens hiding (Index)
import           Data.Default
import           Data.Map.Strict (Map)
import           Data.Set (Set)
import qualified Data.Map.Strict as M
import qualified Data.Set as S



-- | Encode the index of the syntactic or terminal variable.
--
-- In case of grammar-based indexing, keep @indexRange@ empty. The
-- @indexStep@ keeps track of any @+k@ / @-k@ given in the production
-- rules.
--
-- We allow indexing terminals now, too. When glueing together terminals,
-- one might want to be able to differentiate between terminals.

data Index = Index
  { _indexVar   :: String
  , _indexRange :: [String]
  , _indexStep  :: Int
  }
  -- TODO need a version, where we have figured out everything
  -- , i.e. replaced @i+2@ with, say, @1@ @(i==1+2 `mod` 3)@.
  -- Use the @_indexVar = j@ version in the set of syn-vars, but
  -- @_indexVar=x, x \in _indexRange@ in rules?
  deriving (Show)

makeLenses ''Index

-- | Symbols, potentially with an index or more than one.

data SynTermEps
  = SynVar
    { _name   :: String
    , _index  :: [Index]
    }
  | Term
    { _name   :: String
    , _index  :: [Index]
    }
  | Epsilon
  deriving (Show)

makeLenses ''SynTermEps

-- | The length of the list encodes the dimension of the symbol

type STE = [SynTermEps]

-- | Production rules for at-most CFGs.

data Rule = Rule
  { _lhs  :: STE      -- ^ the left-hand side of the rule
  , _attr :: [String] -- ^ the attribute for this rule
  , _rhs  :: [STE]    -- ^ the right-hand side with a collection of terminals and syntactic variables
  }
  deriving (Show)

makeLenses ''Rule

data Grammar = Grammar
  { _synvars  :: Map String SynTermEps  -- ^ regular syntactic variables, without dimension
  , _termsyns :: Map String SynTermEps  -- ^ Terminal synvars are somewhat weird. They are used in Outside grammars, and hold previously calculated inside values.
  , _termvars :: Map String SynTermEps  -- ^ regular terminal symbols
  , _outside  :: Bool   -- ^ Is this an outside grammar
  , _rules    :: [Rule] -- ^ set of production rules
  , _start    :: STE    -- ^ start symbol
  , _params   :: Set String -- ^ any global variables
  , _gname    :: String -- ^ grammar name
  , _write    :: Bool   -- ^ some grammar file requested this grammar to be expanded into code
  }
  deriving (Show)

instance Default Grammar where
  def = Grammar
    { _synvars = M.empty
    , _termsyns = M.empty
    , _termvars = M.empty
    , _outside = False
    , _rules = []
    , _start = []
    , _params = S.empty
    , _gname = ""
    , _write = False
    }

makeLenses ''Grammar


{-

-- * Basic data types for formal grammars.

-- | Grammar indices are enumerable objects
--
-- TODO should we always assume operations "modulo"?

data Enumerable
  = Singular
  | IntBased Integer Integer -- current index, maximum index
--  | Enumerated String [String]
  deriving (Eq,Ord,Show,Typeable,Data)

_IntBased :: Prism' Enumerable (Integer,Integer)
_IntBased = prism (uncurry IntBased) $ f where
  f Singular       = Left  Singular
  f (IntBased c m) = Right (c,m)

ibCurrent = _IntBased . _1

ibModulus = _IntBased . _2

instance Default Enumerable where
  def = Singular

-- | A single-dimensional terminal or non-terminal symbol. @E@ is a special
-- symbol denoting that nothing should be done.
--
-- TODO write Eq,Ord by hand. Fail with error if Enumerable is not equal (this
-- should actually be caught in the combination operations).

-- | 'T' – A terminal symbol (excluding epsilon)
--
-- 'N' – A non-terminal symbol (again, excluding non-terminal epsilons)
--
-- 'E' – Epsilon characters, may be named differently

data TN where
  T :: String               -> TN
  N :: String -> Enumerable -> TN
  E ::                         TN

deriving instance Show     TN
deriving instance Eq       TN
deriving instance Ord      TN
deriving instance Typeable TN
deriving instance Data     TN

isT = \case {T _   -> True; _ -> False}
isN = \case {N _ _ -> True; _ -> False}
isE = \case {E     -> True; _ -> False}

tnName :: Lens' TN String
tnName f (T s  ) = T               <$> f s
tnName f (N s e) = (\s' -> N s' e) <$> f s
tnName f (E    ) = (const E)       <$> f "ε"

_T :: Prism' TN String
_T = prism T $ f where
  f (T s) = Right s
  f z     = Left  z

_N :: Prism' TN (String,Enumerable)
_N = prism (uncurry N) $ f where
  f (N s e) = Right (s,e)
  f z       = Left  z

_E :: Prism' TN ()
_E = prism (const E) $ f where
  f E = Right ()
  f z = Left  z

enumed = _N . _2

-- | Is a symbol of @Outside@ or @Inside@ type?

data InsideOutside = Inside | Outside
  deriving (Show,Eq,Ord,Typeable,Data)

-- | A complete grammatical symbol is multi-dimensional with 0..
-- dimensions.
--
-- TODO we should expand this to three cases: (i) only terminals, (ii) only
-- syntactic variables, (iii) mixed cases

data Symb = Symb
  { inOut    :: InsideOutside
  , getSymbs :: [TN]
  }

deriving instance Show     Symb
deriving instance Eq       Symb
deriving instance Ord      Symb
deriving instance Typeable Symb
deriving instance Data     Symb

symb :: Lens' Symb [TN]
symb f (Symb io xs) = Symb io <$> f xs -- are we sure?

symbInOut :: Lens' Symb InsideOutside
symbInOut f (Symb io xs) = (`Symb` xs) <$> f io

sDim :: Symb -> Int
sDim = length . getSymbs

type instance Index Symb = Int

type instance IxValue Symb = TN

instance Ixed Symb where
  ix k f (Symb io xs) = Symb io <$> ix k f xs
  {-# INLINE ix #-}

-- | A production rule goes from a left-hand side (lhs) to a right-hand side
-- (rhs). The rhs is evaluated using a function (fun).
--
-- TODO These production rules currently do not allow "typical"
-- context-sensitive grammars with terminal symbols on the left-hand side.

data Rule = Rule
  { _lhs :: Symb
  , _fun :: [String] -- Fun
  , _rhs :: [Symb]
  }
  deriving (Eq,Ord,Show,Typeable,Data)

makeLenses ''Rule

-- | A complete grammar with a set of terminal symbol (tsyms), non-terminal
-- symbol (nsyms), production rules (rules) and a start symbol (start).
--
-- TODO Combined terminal and non-terminal symbols in multi-tape grammars are
-- denoted as non-terminal symbols.
--
-- TODO rename epsis -> esyms
--
-- TODO tsyms, esyms are not symbols but should just be 1-dim things ...
--
-- TODO nsyms should maybe be 1-dim, then have another thing for the multidim things

data Grammar = Grammar
  { _tsyms :: Set Symb
  , _nsyms :: Set Symb
  , _nIsms :: Set Symb      -- in case of an outside grammar, this contains the inside syntactic variables that now act as "kind-of" terminals
  , _epsis :: Set TN
  , _rules :: Set Rule
  , _start :: Maybe Symb
  , _name  :: String
  } deriving (Show,Data,Typeable)

makeLenses ''Grammar

-- | Determines if this is an outside grammar

isOutsideGrammar :: Grammar -> Bool
isOutsideGrammar g = anyOf folded (\(Symb io _) -> io==Outside) $ g^.nsyms

-- | the dimension of the grammar. Grammars with no symbols have dimension 0.

gDim :: Grammar -> Int
gDim g
  | Just (x,_) <- S.minView (g^.nsyms) = length $ x^.symb
  | Just (x,_) <- S.minView (g^.tsyms) = length $ x^.symb
  | otherwise                          = 0

-- | Helper function giving the grammar name. Will add an @Outside@ prefix,
-- where necessary.

grammarName :: Grammar -> String
grammarName g = if isOutsideGrammar g then "Outside" ++ g^.name else "" ++ g^.name

-- * Helper functions on rules and symbols.

-- | Symb is completely in terminal form.

isSymbT :: Symb -> Bool
isSymbT (Symb io xs) = allOf folded tTN xs && anyOf folded (\case (T _) -> True ; _ -> False) xs

tTN :: TN -> Bool
tTN (T _  ) = True
tTN (E    ) = True
tTN (N _ _) = False

isSymbE :: Symb -> Bool
isSymbE (Symb io xs) = allOf folded (\case E -> True ; _ -> False) xs

-- | Symb is completely in non-terminal form.

isSymbN :: Symb -> Bool
isSymbN (Symb io xs) = allOf folded nTN xs && anyOf folded (\case (N _ _) -> True ; _ -> False) xs

{-
-- | Generalized non-terminal symbol with at least one non-terminal Symb.

nSymbG :: Symb -> Bool
nSymbG (Symb xs) = allOf folded nTN xs && anyOf folded (\case (N _ _) -> True ; _ -> False) xs
-}

nTN :: TN -> Bool
nTN (N _ _) = True
nTN (E    ) = True
nTN (T _  ) = False



-- * Determine grammar types
--
-- For grammars where the number of non-terminal symbols is restricted, we
-- allow as non-terminal also the generalized variants that have partial
-- terminal symbols.
--
-- TODO maybe restrict those to epsilon-type terminals in generalized
-- non-terminals.

-- | Left-linear grammars have at most one non-terminal on the RHS. It is the
-- first symbol.

isLeftLinear :: Grammar -> Bool
isLeftLinear g = allOf folded isll $ g^.rules where
  isll :: Rule -> Bool
  isll (Rule l _ []) = isSymbN l
  isll (Rule l _ rs) = isSymbN l && (allOf folded (not . isSymbN) $ tail rs) -- at most one non-terminal

-- | Right-linear grammars have at most one non-terminal on the RHS. It is the
-- last symbol.

isRightLinear :: Grammar -> Bool
isRightLinear g = allOf folded isrl $ g^.rules where
  isrl :: Rule -> Bool
  isrl (Rule l _ []) = isSymbN l
  isrl (Rule l _ rs) = isSymbN l && (allOf folded (not . isSymbN) $ init rs)

-- | Linear grammars just have a single non-terminal on the right-hand side.

isLinear :: Grammar -> Bool
isLinear g = error "isLinear: write me" -- allOf folded ((<=1) . length . filter nSymbG


-- * Different normal forms for grammars.

-- | Transform a grammar into CNF. (cf. COL-2007)
--
-- TODO make sure we use a variant that computes small grammars.

chomskyNF :: Grammar -> Grammar
chomskyNF = error "chomsky"

isChomskyNF :: Grammar -> Bool
isChomskyNF g = allOf folded isC $ g^.rules where
  isC :: Rule -> Bool
  isC (Rule _ _ [s])   = isSymbT s
  isC (Rule _ _ [s,t]) = isSymbN s && isSymbN t
  isC _                = False

-- | Transform grammar into GNF.
--
-- http://dl.acm.org/citation.cfm?id=321254

greibachNF :: Grammar -> Grammar
greibachNF = error "gnf"

-- | Check if grammar is in Greibach Normal Form

isGreibachNF :: Grammar -> Bool
isGreibachNF g = allOf folded isG $ g^.rules where
  isG :: Rule -> Bool
  isG (Rule _ _ (t:ns)) = isSymbT t && all isSymbN ns
  isG _                 = False

-- | A grammar is epsilon-free if no rule has an empty RHS, resp. any rhs-symb
-- is completely non-empty.
--
-- TODO we should tape-split multi-tape grammars here and make sure that all
-- individual tapes are epsilon-free as otherwise we can generate cases where
-- the epsilon-aligned symbols lead to weird problems. So split into single
-- tapes, then check.

epsilonFree :: Grammar -> Bool
epsilonFree g = allOf folded eFree $ g^.rules where
  eFree :: Rule -> Bool
  eFree (Rule l _ r) = undefined -- l == g^.start || (not $ null r) || anyOf folded (epsFree $ g^.start) r
  epsFree :: Symb -> Symb -> Bool
  epsFree = undefined

-- | Collect all non-terminal symbols from the rules

collectSymbN :: Grammar -> [Symb]
collectSymbN g = nub . sort . filter isSymbN $ (g^..rules.folded.lhs) ++ (g^..rules.folded.rhs.folded)

-- | Collect the syntactic variable symbols for either inside or outside,
-- depending on the grammar

collectInOutSymbN :: Grammar -> [Symb]
collectInOutSymbN g = filter f xs where
  xs = collectSymbN g
  f (Symb Outside _) = isO
  f (Symb Inside  _) = not isO
  isO = isOutsideGrammar g

-- | Collect all terminal symbols from the rules (for cfg's it's not really
-- needed to include the lhs).

collectSymbT :: Grammar -> [Symb]
collectSymbT g = nub . sort . filter isSymbT $ (g^..rules.folded.lhs) ++ (g^..rules.folded.rhs.folded)

-}

