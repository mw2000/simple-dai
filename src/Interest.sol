pragma solidity ^0.8.13;

library Interest {
    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;

    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = ((x * y) + (RAY / 2)) / RAY;
    }

    function rpow(uint x, uint n) internal pure returns (uint z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }

    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = ((x * RAY) + (y / 2)) / y;
    }

    function accrueInterest(uint _principal, uint _rate, uint _age) external pure returns (uint) {
        return rmul(_principal, rpow(_rate, _age));
    }

    function yearlyRateToRay(uint _rateWad) external pure returns (uint) {
        return wadToRay(1 ether) + rdiv(wadToRay(_rateWad), weiToRay(365*86400));
    }

    // Go from wad (10**18) to ray (10**27)
    function wadToRay(uint _wad) internal pure returns (uint) {
        return _wad * 10 ** 9;
    }

    // Go from wei to ray (10**27)
    function weiToRay(uint _wei) internal pure returns (uint) {
        return _wei * 10 ** 27;
    } 
}

// Referenced from - https://github.com/wolflo/solidity-interest-helper/