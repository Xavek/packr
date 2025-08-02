#[starknet::interface]
pub trait IStarknetHLTC<TContractState> {
    /// This does transfer the amount of token to the claim address if provided with correct secret
    fn claim_with_secret(ref self: TContractState, secret: u256);
    fn refund_to_resolver(ref self: TContractState);
}

use starknet::{ContractAddress};

// A simplified interface for a fungible token standard.
#[starknet::interface]
pub trait IERC20<TContractState> {
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
}


#[starknet::contract]
mod StarknetHLTC {
    use core::starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::keccak::*;
    use core::array::{ArrayTrait, Span};
    use super::{IERC20DispatcherTrait, IERC20Dispatcher};
    #[storage]
    struct Storage {
        balance: felt252,
        hash_lock: u256,
        resolver: ContractAddress,
        claim_address: ContractAddress,
        amount: u256,
        token_contract: ContractAddress,
        time_lock: u64,
        is_claimed: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct STRKNTHLTCDeployed {
        pub hash_lock: u256,
        pub resolver: ContractAddress,
        pub tokenAddress: ContractAddress,
        pub claimAddress: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Claimed {
        pub claimAddress: ContractAddress,
        pub amount: u256,
    }

    #[derive(starknet::Event, Drop)]
    #[event]
    enum Event {
        STRKNTHLTCDeployed: STRKNTHLTCDeployed,
        Claimed: Claimed,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        hash_lock: u256,
        time_lock: u64,
        resolver: ContractAddress,
        token_contract: ContractAddress,
        amount: u256,
        user_address: ContractAddress,
    ) {
        self.hash_lock.write(hash_lock);
        self.time_lock.write(get_block_timestamp() + time_lock);
        self.resolver.write(resolver);
        self.token_contract.write(token_contract);
        self.amount.write(amount);
        self.claim_address.write(user_address);
        self
            .emit(
                STRKNTHLTCDeployed {
                    hash_lock,
                    resolver,
                    tokenAddress: token_contract,
                    claimAddress: user_address,
                    amount,
                },
            )
    }

    #[abi(embed_v0)]
    impl HLTCStarknetImpl of super::IStarknetHLTC<ContractState> {
        fn claim_with_secret(ref self: ContractState, secret: u256) {
            assert(!self.is_claimed.read(), 'Already claimed or canceled');
            assert(self.time_lock.read() < get_block_timestamp(), 'Time Passed');
            let secret_ser = array![secret].span();
            // this keccak with big endian is used by eth as well so same hash would be generated?
            let computed_hash_lock = keccak_u256s_be_inputs(secret_ser);
            assert(computed_hash_lock == self.hash_lock.read(), 'Invalid Secret');
            let token_dispatcher = IERC20Dispatcher {
                contract_address: self.token_contract.read(),
            };
            token_dispatcher.transfer(self.claim_address.read(), self.amount.read());
            self.is_claimed.write(true);
            self
                .emit(
                    Claimed { claimAddress: self.claim_address.read(), amount: self.amount.read() },
                );
        }

        fn refund_to_resolver(ref self: ContractState) {
            assert(!self.is_claimed.read(), 'Already claimed or canceled');
            assert(get_block_timestamp() > self.time_lock.read(), 'Timelock not finished');
            let caller = get_caller_address();
            assert(caller == self.resolver.read(), 'Not resolver call');
            let token_dispatcher = IERC20Dispatcher {
                contract_address: self.token_contract.read(),
            };
            token_dispatcher.transfer(self.claim_address.read(), self.amount.read());
            self.is_claimed.write(true);
            self.emit(Claimed { claimAddress: self.resolver.read(), amount: self.amount.read() });
        }
    }
}
