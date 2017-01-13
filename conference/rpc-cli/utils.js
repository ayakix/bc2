const deasync = require('deasync');
const colors = require('colors');

const utils = {
    verifyBTC(btc) {
        return (Math.trunc(btc * 100000000) / 100000000) == btc;
    },
    btcFromSatoshi(satoshi) {
        return satoshi / 100000000;
    },
    satoshiFromBTC(btc) {
        return btc * 100000000;
    },
    kvpPrint(kvp) {
        let v = '';
        for (let i = 0; i < kvp.length; i++) {
            const key = kvp[i++];
            const val = kvp[i];
            if (key == '') {
                v += '\n';
                i--;
            } else {
                v += key.cyan + ('' + val).yellow + '\n';
            }
        }
        console.log(v.substr(0, v.length - 1));
    },
    deasyncObject(object, synchronousByNature = []) {
        const target = object.prototype || object;
        for (const m of Object.keys(target)) {
          if (!synchronousByNature[m] && m[m.length-1] !== 'O')
            target[`${m}S`] = deasync(target[m]);
        }
    },
};

module.exports = utils;
