{-# Language TemplateHaskell #-}
{-# Language FlexibleInstances #-}

module Data.MessagePack.Derive (
  derivePack,
  deriveUnpack,
  deriveObject,
  ) where

import Control.Monad
import Control.Monad.Error () -- for MonadPlus instance of Either e
import Data.Char
import Data.List
import Language.Haskell.TH
import Language.Haskell.TH.Syntax

import Data.MessagePack.Assoc
import Data.MessagePack.Pack
import Data.MessagePack.Unpack
import Data.MessagePack.Object

derivePack :: Name -> Q [Dec]
derivePack tyName = do
  info <- reify tyName
  d <- case info of
    TyConI (DataD _ {- cxt -} name tyVars cons _ {- derivings -}) -> do
      ds <- [d| put v = $(caseE [| v |] (map alt cons)) |]
      instanceD (cx tyVars) (ct ''Packable name tyVars) $
        map return ds

    _ -> error $ "cant derive Packable: " ++ show tyName
  return [d]

  where
    alt (NormalC conName elms) = do
      vars <- replicateM (length elms) (newName "v")
      match (conP conName $ map varP vars)
        (normalB [| put $(tupE $ map varE vars) |])
        []

    alt (RecC conName elms) = do
      vars <- replicateM (length elms) (newName "v")
      match (conP conName $ map varP vars)
        (normalB
         [| put $ Assoc
              $(listE [ [| ( $(return $ LitE $ StringL $ key conName fname)
                           , toObject $(varE v)) |]
                      | (v, (fname, _, _)) <- zip vars elms])
          |])
        []

    alt c = error $ "unsupported constructor: " ++ pprint c


deriveUnpack :: Name -> Q [Dec]
deriveUnpack tyName = do
  info <- reify tyName
  d <- case info of
    TyConI (DataD _ {- cxt -} name tyVars cons _ {- derivings -}) -> do
      ds <- [d| get = $(foldl1 (\x y -> [| $x `mplus` $y |]) $ map alt cons) |]
      instanceD (cx tyVars) (ct ''Unpackable name tyVars) $
        map return ds

    _ -> error $ "cant derive Unpackable: " ++ show tyName
  return [d]

  where
    alt (NormalC conName elms) = do
      vars <- replicateM (length elms) (newName "v")
      doE [ bindS (tupP $ map varP vars) [| get |]
          , noBindS [| return $(foldl appE (conE conName) $ map varE vars) |]
          ]

    alt (RecC conName elms) = do
      var <- newName "v"
      vars <- replicateM (length elms) (newName "w")
      doE $ [ bindS (conP 'Assoc [varP var]) [| get |] ]
            ++ zipWith (binds conName var) vars elms ++
            [ noBindS [| return $(foldl appE (conE conName) $ map varE vars) |] ]

    alt c = error $ "unsupported constructor: " ++ pprint c

    binds conName var res (fname, _, _) =
      bindS (varP res)
            [| failN $ lookup $(return $ LitE $ StringL $ key conName fname)
                              $(varE var) |]

deriveObject :: Name -> Q [Dec]
deriveObject tyName = do
  g <- derivePack tyName
  p <- deriveUnpack tyName
  info <- reify tyName
  o <- case info of
    TyConI (DataD _ {- cxt -} name tyVars cons _ {- derivings -}) ->
      -- use default implement
      instanceD (cx tyVars) (ct ''OBJECT name tyVars) []
    _ -> error $ "cant derive Object: " ++ show tyName
  return $ g ++ p ++ [o]

failN Nothing = mzero
failN (Just a) =
  case tryFromObject a of
    Left _ -> mzero
    Right v -> return v

cx tyVars =
  cxt [ classP cl [varT tv]
      | cl <- [''Packable, ''Unpackable, ''OBJECT]
      , PlainTV tv <- tyVars ]

ct tc tyName tyVars =
  appT (conT tc) $ foldl appT (conT tyName) $
  map (\(PlainTV n) -> varT n) tyVars

key conName fname
  | (prefix ++ "_") `isPrefixOf` sFname && length sFname > length prefix + 1 =
    drop (length prefix + 1) sFname  
  | prefix `isPrefixOf` sFname && length sFname > length prefix =
    uncapital $ drop (length prefix) sFname
  | otherwise = sFname
  where
    prefix = map toLower $ nameBase conName
    sFname = nameBase fname
    uncapital (c:cs) | isUpper c = toLower c : cs
    uncapital cs = cs
