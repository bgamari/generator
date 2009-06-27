{-# OPTIONS -O2 -Wall #-}

-- To be replaced with (or changed to) Control.Generator (Consumer/Producer) package
-- as decided with Eyal
-- am still using it for now
-- Iterator will be replaced with ProducerT
-- IteratesT will be called ConsumerT

module Data.Iterator (
  Iterator, IteratesT,
  empty, evalIteratesT, cons, cons',
  iterator, mmerge, next, nil, processRest
  ) where

import Control.Monad.State (StateT, evalStateT, get, put)
import Control.Monad.Trans (MonadTrans(..))
import Data.Maybe (fromMaybe)

type Iterator' v m = m (Maybe (v, Iterator v m))
newtype Iterator v m = CIterator (Iterator' v m)

iterator :: Iterator' v m -> Iterator v m
iterator = CIterator

mmerge :: Monad m => m (Iterator v m) -> Iterator v m
mmerge mIter =
  iterator $ do
  CIterator iter <- mIter
  iter

nil :: Monad m => Iterator' v m
nil = return Nothing

empty :: Monad m => Iterator v m
empty = iterator nil

cons'' :: Monad m => v -> Iterator v m -> Iterator' v m
cons'' v = return . Just . ((,) v)

cons :: Monad m => a -> Iterator a m -> Iterator a m
cons v = iterator . cons'' v

-- when constructing iterators
-- sometimes it's easier to do "cons' $ do"
cons' :: Monad m => v -> Iterator' v m -> Iterator' v m
cons' v = cons'' v . iterator

type IteratesT' v m a = StateT (Maybe (Iterator v m)) m a
newtype IteratesT v m a = CIteratesT {
  uIteratesT :: IteratesT' v m a
  }

instance Monad m => Monad (IteratesT v m) where
  return = CIteratesT . return
  fail = CIteratesT . fail
  (CIteratesT a) >>= b = CIteratesT $ a >>= uIteratesT . b

instance MonadTrans (IteratesT v) where
  lift = CIteratesT . lift

evalIteratesT :: Monad m => IteratesT v m a -> Iterator v m -> m a
evalIteratesT (CIteratesT i) = evalStateT i . Just

next :: Monad m => IteratesT v m (Maybe v)
next =
  CIteratesT $ do
  x <- get
  case x of
    Nothing -> return Nothing
    Just (CIterator getNext) -> r =<< lift getNext
  where
    r Nothing = do
      put Nothing
      return Nothing
    r (Just (val, iter)) = do
      put $ Just iter
      return $ Just val

processRest :: Monad m => IteratesT a m b -> IteratesT a m (m b)
processRest process =
  CIteratesT $ do
  mRest <- get
  let rest = fromMaybe empty mRest
  put Nothing
  return $ evalIteratesT process rest

