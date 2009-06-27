{-# OPTIONS -O2 -Wall #-}

module Data.Iterator.Tools (
  append, execute, fromList, iconcat,
  ifoldl, ifoldl', ifoldr, ifoldr', ilength, imap,
  ifilter, itake, iTakeWhile, toList,
  toIteratesT
  ) where

import Control.Monad (liftM)
import Control.Monad.Trans (lift)
import Data.Iterator (
  IteratesT, Iterator, cons, empty, evalIteratesT,
  mmerge, next, processRest)

-- naming: for everything that's in prelude I add an "i" prefix,
-- for convinient importing

ifoldl :: Monad m => (a -> b -> m a) -> a -> Iterator b m -> m a
ifoldl func startVal =
  evalIteratesT $ r startVal =<< next
  where
    r s Nothing = return s
    r s (Just v) = do
      x <- lift (func s v)
      r x =<< next

ifoldl' :: Monad m => (a -> b -> a) -> a -> Iterator b m -> m a
ifoldl' step =
  ifoldl step'
  where
    step' a b =
      x `seq` return x
      where
        x = step a b

-- consFunc takes "m b" and not "b" so could avoid running the rest
ifoldr :: Monad m => (a -> m b -> m b) -> m b -> Iterator a m -> m b
ifoldr consFunc nilFunc =
  evalIteratesT $ r =<< next
  where
    r Nothing = lift nilFunc
    r (Just v) =
      lift . consFunc v =<< processRest (ifoldr consFunc nilFunc)

-- for operations that build Iterators, combine step with the mmerge etc boiler-plate
ifoldr' :: Monad m => (b -> Iterator a m -> Iterator a m) -> Iterator a m -> Iterator b m -> Iterator a m
ifoldr' consFunc start =
  mmerge . ifoldr step (return start)
  where
    step x = return . consFunc x . mmerge

imap :: Monad m => (a -> m b) -> Iterator a m -> Iterator b m
imap func =
  ifoldr' step empty
  where
    step a bs =
      mmerge $ do
      b <- func a
      return $ cons b bs

ifilter :: Monad m => (a -> m Bool) -> Iterator a m -> Iterator a m
ifilter cond =
  ifoldr' r empty
  where
    r x xs =
      mmerge $ do
      b <- cond x
      return $ if b then cons x xs else xs

-- uses ifoldl because I think with ifoldr it would use much mem, right?
toList :: (Monad m) => Iterator a m -> m [a]
toList =
  liftM reverse . ifoldl step []
  where
    step xs x = return $ x : xs

iTakeWhile :: Monad m => (a -> Bool) -> Iterator a m -> Iterator a m
iTakeWhile func =
  ifoldr' r empty
  where
    r x xs = if func x then cons x xs else empty

fromList :: (Monad m) => [a] -> Iterator a m
fromList = foldr cons empty

append :: Monad m => Iterator a m -> Iterator a m -> Iterator a m
append a b = ifoldr' cons b a

iconcat :: Monad m => Iterator (Iterator a m) m -> Iterator a m
iconcat = ifoldr' append empty

execute :: Monad m => Iterator a m -> m ()
execute = ifoldl' const ()

ilength :: (Monad m, Integral i) => Iterator a m -> m i
ilength = ifoldl' (const . (+ 1))  0

itake :: (Monad m, Integral i) => i -> Iterator a m -> Iterator a m
itake count =
  mmerge . evalIteratesT (r0 count)
  where
    r0 0 = return empty
    r0 c = r1 c =<< next
    r1 _ Nothing = return empty
    r1 c (Just v) = do
      rest <- r0 (c-1)
      return $ cons v rest

-- opposite of evalIteratesT
toIteratesT :: Monad m => (Iterator v m -> m a) -> IteratesT v m a
toIteratesT process = lift =<< processRest process

