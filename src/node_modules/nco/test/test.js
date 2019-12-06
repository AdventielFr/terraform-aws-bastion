
const nco = require('./../lib/index.js');
const assert = require('assert');

describe('nco', function() {
  const defaultInt = 1234;
  it('should return the default value when variable is null', function() {
    const value = nco(null, defaultInt);
    assert.equal(defaultInt, value);
  });

  it('should return the default value when variable is undefined', function() {
    const undefinedVar;
    const value = nco(undefinedVar, defaultInt);
    assert.equal(defaultInt, value);
  });

  it('should return false when the variable is false', function() {
    const value = nco(false, defaultInt);
    assert.equal(false, value);
  });

  it('should return true when the variable is true', function() {
    const value = nco(true, defaultInt);
    assert.equal(true, value);
  });

  it('should return 0 when the variable is 0', function() {
    const value = nco(0, defaultInt);
    assert.equal(0, value);
  });

  it('should return -17 when the variable is -17', function() {
    const value = nco(-17, defaultInt);
    assert.equal(-17, value);
  });

  it('should return "" when the variable is "" (empty string)', function() {
    const value = nco('', defaultInt);
    assert.equal('', value);
  });

});
