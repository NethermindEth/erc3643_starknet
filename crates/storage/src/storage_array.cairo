use core::num::traits::Zero;
use starknet::ContractAddress;
use starknet::storage::{
    Map, Mutable, StoragePath, StoragePathEntry, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};

pub trait StorageArrayTrait<T> {
    type ElementType;
    fn get(self: T, index: u64) -> Option<StoragePath<Self::ElementType>>;
    fn at(self: T, index: u64) -> StoragePath<Self::ElementType>;
    fn len(self: T) -> u64;
}

pub trait MutableStorageArrayTrait<T> {
    type ElementType;
    fn get(self: T, index: u64) -> Option<StoragePath<Mutable<Self::ElementType>>>;
    fn at(self: T, index: u64) -> StoragePath<Mutable<Self::ElementType>>;
    fn len(self: T) -> u64;
    fn append(self: T) -> StoragePath<Mutable<Self::ElementType>>;
    fn delete(self: T, index: u64);
    fn clear(self: T);
}

//********************************************************
//             StorageArray for ContractAddress
//********************************************************
#[starknet::storage_node]
pub struct StorageArrayContractAddress {
    vec: Map<u64, ContractAddress>,
    len: u64,
}

pub impl StorageArrayContractAddressImpl of StorageArrayTrait<
    StoragePath<StorageArrayContractAddress>,
> {
    type ElementType = ContractAddress;
    fn get(
        self: StoragePath<StorageArrayContractAddress>, index: u64,
    ) -> Option<StoragePath<Self::ElementType>> {
        let vec_len = self.len.read();
        if index < vec_len {
            return Option::Some(self.vec.entry(index));
        }
        Option::None
    }

    fn at(
        self: StoragePath<StorageArrayContractAddress>, index: u64,
    ) -> StoragePath<Self::ElementType> {
        assert!(index < self.len.read(), "Index out of bounds");
        self.vec.entry(index)
    }

    fn len(self: StoragePath<StorageArrayContractAddress>) -> u64 {
        self.len.read()
    }
}

pub impl MutableStorageArrayContractAddressImpl of MutableStorageArrayTrait<
    StoragePath<Mutable<StorageArrayContractAddress>>,
> {
    type ElementType = ContractAddress;
    fn delete(self: StoragePath<Mutable<StorageArrayContractAddress>>, index: u64) {
        let len = self.len.read();
        assert!(index < len, "Index out of bounds");
        let last_element_storage_path = self.vec.entry(len - 1);
        if index != len - 1 {
            let last_element = last_element_storage_path.read();
            self.vec.entry(index).write(last_element);
        }
        last_element_storage_path.write(Zero::zero());
        self.len.write(len - 1);
    }

    fn append(
        self: StoragePath<Mutable<StorageArrayContractAddress>>,
    ) -> StoragePath<Mutable<Self::ElementType>> {
        let len = self.len.read();
        self.len.write(len + 1);
        self.vec.entry(len)
    }

    fn get(
        self: StoragePath<Mutable<StorageArrayContractAddress>>, index: u64,
    ) -> Option<StoragePath<Mutable<Self::ElementType>>> {
        let vec_len = self.len.read();
        if index < vec_len {
            return Option::Some(self.vec.entry(index));
        }
        Option::None
    }

    fn at(
        self: StoragePath<Mutable<StorageArrayContractAddress>>, index: u64,
    ) -> StoragePath<Mutable<Self::ElementType>> {
        assert!(index < self.len.read(), "Index out of bounds");
        self.vec.entry(index)
    }

    fn len(self: StoragePath<Mutable<StorageArrayContractAddress>>) -> u64 {
        self.len.read()
    }

    fn clear(self: StoragePath<Mutable<StorageArrayContractAddress>>) {
        self.len.write(0);
    }
}

pub impl StorageArrayContractAddressIndexView of core::ops::IndexView<
    StoragePath<StorageArrayContractAddress>, u64,
> {
    type Target = StoragePath<ContractAddress>;
    fn index(self: @StoragePath<StorageArrayContractAddress>, index: u64) -> Self::Target {
        (*self).at(index)
    }
}

pub impl MutableStorageArrayContractAddressIndexView of core::ops::IndexView<
    StoragePath<Mutable<StorageArrayContractAddress>>, u64,
> {
    type Target = StoragePath<Mutable<ContractAddress>>;
    fn index(self: @StoragePath<Mutable<StorageArrayContractAddress>>, index: u64) -> Self::Target {
        (*self).at(index)
    }
}

pub impl ContractAddressVecToContractAddressArray of Into<
    StoragePath<StorageArrayContractAddress>, Array<ContractAddress>,
> {
    fn into(self: StoragePath<StorageArrayContractAddress>) -> Array<ContractAddress> {
        let mut array = array![];
        for i in 0..self.len() {
            array.append(self[i].read());
        };
        array
    }
}

pub impl MutableContractAddressVecToContractAddressArray of Into<
    StoragePath<Mutable<StorageArrayContractAddress>>, Array<ContractAddress>,
> {
    fn into(self: StoragePath<Mutable<StorageArrayContractAddress>>) -> Array<ContractAddress> {
        let mut array = array![];
        for i in 0..self.len() {
            array.append(self[i].read());
        };
        array
    }
}
