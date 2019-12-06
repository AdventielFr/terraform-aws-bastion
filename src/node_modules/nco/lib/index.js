
const nco = function(variable, defaultValue) {
  return (variable === null || typeof variable === 'undefined') ? defaultValue : variable;
}
module.exports = nco;
