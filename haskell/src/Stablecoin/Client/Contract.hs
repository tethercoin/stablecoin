-- SPDX-FileCopyrightText: 2020 TQ Tezos
-- SPDX-License-Identifier: MIT

module Stablecoin.Client.Contract
  ( parseStablecoinContract
  , parseRegistryContract
  , mkInitialStorage
  , mkRegistryStorage
  , InitialStorageData(..)
  ) where

import Data.FileEmbed (embedStringFile)
import qualified Data.Map.Strict as Map
import Michelson.Runtime (parseExpandContract)
import Michelson.Text (MText)
import Michelson.Typed (BigMap(BigMap))
import qualified Michelson.Untyped as U
import Morley.Client (AddressOrAlias)
import Tezos.Address (Address)
import Util.Named ((.!))

import Lorentz.Contracts.Stablecoin
  (MetadataRegistryStorage, pattern RegistryMetadata, Storage, mkTokenMetadata, stablecoinPath, metadataRegistryContractPath)

-- | Parse the stablecoin contract.
parseStablecoinContract :: MonadThrow m => m U.Contract
parseStablecoinContract =
  either throwM pure $
    parseExpandContract
      (Just stablecoinPath)
      $(embedStringFile stablecoinPath)

-- | Parse the metadata registry contract.
parseRegistryContract :: MonadThrow m => m U.Contract
parseRegistryContract =
  either throwM pure $
    parseExpandContract
      (Just metadataRegistryContractPath)
      $(embedStringFile metadataRegistryContractPath)

type family ComputeRegistryAddressType a where
  ComputeRegistryAddressType Address = Address
  ComputeRegistryAddressType AddressOrAlias = Maybe AddressOrAlias

-- | The data needed in order to create the stablecoin contract's initial storage.
data InitialStorageData addr = InitialStorageData
  { isdMasterMinter :: addr
  , isdContractOwner :: addr
  , isdPauser :: addr
  , isdTransferlist :: Maybe addr
  , isdTokenSymbol :: MText
  , isdTokenName :: MText
  , isdTokenDecimals :: Natural
  , isdTokenMetadataRegistry :: ComputeRegistryAddressType addr
  }

-- | Construct the stablecoin contract's initial storage in order to deploy it.
mkInitialStorage :: InitialStorageData Address -> Storage
mkInitialStorage (InitialStorageData {..}) =
  (
    (
      ( #ledger .! mempty
      , #minting_allowances .! mempty
      )
    , ( #operators .! mempty
      , #paused .! False
      )
    )
  , (
      ( #roles .!
        (
          ( #master_minter .! isdMasterMinter
          , #owner .! isdContractOwner
          )
        , ( #pauser .! isdPauser
          , #pending_owner_address .! Nothing
          )
        )
      , #token_metadata_registry .! isdTokenMetadataRegistry
      )
    , #transferlist_contract .! isdTransferlist
    )
  )

-- | Constuct the stablecoin metadata
mkRegistryStorage :: MText -> MText -> Natural -> MetadataRegistryStorage
mkRegistryStorage symbol name decimals = RegistryMetadata $ BigMap $ Map.singleton 0 $
  mkTokenMetadata $
    ( #token_id .! 0
    , #mdr .!
      ( #symbol .! symbol
      , #mdr2 .!
        ( #name .! name
        , #mdr3 .!
          ( #decimals .! decimals
          , #extras .! mempty
          )
        )
      )
    )
