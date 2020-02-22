package eth

import (
	"nulink/core/logger"
	"fmt"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/gobuffalo/packr"
	"github.com/pkg/errors"
	"github.com/tidwall/gjson"
)

// Contract holds the solidity contract's parsed ABI
type Contract struct {
	ABI abi.ABI
}

func getContract(name string, box packr.Box) (*Contract, error) {
	jsonFile, err := box.Find(name + ".json")
	if err != nil {
		return nil, errors.Wrap(err, "unable to read contract JSON")
	}

	abiBytes := gjson.GetBytes(jsonFile, "compilerOutput.abi")
	abiParsed, err := abi.JSON(strings.NewReader(abiBytes.Raw))
	if err != nil {
		return nil, err
	}

	return &Contract{abiParsed}, nil
}

// GetContract loads the contract JSON file from ../../evm-contracts/abi/v0.4
// and parses the ABI JSON contents into an abi.ABI object
//
// NB: These contracts can be built by running
//    yarn setup:contracts
// in the base project directory.
func GetContract(name string) (*Contract, error) {
	box := packr.NewBox("../../evm-contracts/abi/v0.4")
	return getContract(name, box)
}

// GetV6Contract loads the contract JSON file from ../../evm-contracts/abi/v0.6
// and parses the ABI JSON contents into an abi.ABI object
//
// NB: These contracts can be built by running
//    yarn setup:contracts
// in the base project directory.
func GetV6Contract(name string) (*Contract, error) {
	box := packr.NewBox("../../evm-contracts/abi/v0.6")
	return getContract(name, box)
}

// EncodeMessageCall encodes method name and arguments into a byte array
// to conform with the contract's ABI
func (contract *Contract) EncodeMessageCall(method string, args ...interface{}) ([]byte, error) {
	return contract.ABI.Pack(method, args...)
}

// GetMethodID returns the first 4 bytes of the keccak256 hash of the method
// signature. The passed method is simply the method name, not the parameters,
// as defined by go-ethereum ABI Methods
//
// e.g.
// There are two functions have same name:
// * foo(int,int)
// * foo(uint,uint)
// The method name of the first one will be resolved as foo while the second one
// will be resolved as foo0.
func (contract *Contract) GetMethodID(method string) ([]byte, error) {
	mabi, found := contract.ABI.Methods[method]
	if !found {
		return []byte{}, errors.New("unable to find contract method " + method)
	}
	return mabi.ID(), nil
}

// MustGetV6ContractEventID finds the event for the given contract by searching
// embedded contract assets from evm/, or panics if not found.
func MustGetV6ContractEventID(name, eventName string) common.Hash {
	contract, err := GetV6Contract(name)
	if err != nil {
		logger.Panic(fmt.Errorf("unable to find contract %s", name))
	}

	event, found := contract.ABI.Events[eventName]
	if !found {
		logger.Panic(fmt.Errorf("unable to find event %s for contract %s", eventName, name))
	}
	return event.ID()
}
