## Compatibility with other libraries

### [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts/)

FPS is designed for compatibility with OpenZeppelin contracts versions prior to v5.0. This design decision aligns with the current limitations of Solidity `^0.8.20`, as detailed in [Solidity Issue #14254](https://github.com/ethereum/solidity/issues/14254). Developers should note that some Layer Two solutions may not be compatible with this version of Solidity, influencing our decision to limit compatibility.


