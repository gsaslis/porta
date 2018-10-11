require 'test_helper'

class Finance::BillingStrategy::ResultsTest < ActiveSupport::TestCase

  test 'success' do
    results = Finance::BillingStrategy::Results.new(Date.new(2012,12,12))
    b1 = Finance::BillingStrategy.new({ account_id: 1 }, without_protection: true)
      .tap { |bs| bs.stubs(failed_buyers: []) }
    b2 = Finance::BillingStrategy.new({ account_id: 2 }, without_protection: true)
      .tap { |bs| bs.stubs(failed_buyers: []) }

    results.start(b1)
    results.success(b1)

    results.start(b2)
    results.success(b2)

    assert results.successful?
    assert_equal 0, results.providers_failed_count
    assert_equal 0, results.buyers_failed_count
  end

  test 'failed buyers' do
    results = Finance::BillingStrategy::Results.new(Date.new(2012,12,12))

    # ok
    bs = Finance::BillingStrategy.new({ account_id: 1 }, without_protection: true)
      .tap { |bs| bs.stubs(failed_buyers: []) }
    results.start(bs)
    results.success(bs)

    # with errors
    bs = Finance::BillingStrategy.new({ account_id: 2 }, without_protection: true)
      .tap { |bs| bs.stubs(failed_buyers: [4,5,6]) }
    results.start(bs)
    results.success(bs)

    refute results.successful?
    assert_equal 0, results.providers_failed_count
    assert_equal 3, results.buyers_failed_count
    assert_equal({ 2 => { errors: [ 4,5,6 ], success: true }}, results.with_errors)
  end

  test 'failed providers' do
    results = Finance::BillingStrategy::Results.new(Date.new(2012,12,12))
    bs1 = Finance::BillingStrategy.new({ account_id: 101 }, without_protection: true)
      .tap { |bs| bs.stubs(failed_buyers: [1,2,3]) }
    bs2 = Finance::BillingStrategy.new({ account_id: 202 }, without_protection: true)
      .tap { |bs| bs.stubs(failed_buyers: [4,5]) }
    bs3 = Finance::BillingStrategy.new({ account_id: 303 }, without_protection: true)
      .tap { |bs| bs.stubs(failed_buyers: []) }

    results.start(bs1)
    results.success(bs1)
    results.start(bs2)
    results.success(bs2)
    results.start(bs3)
    results.failure(bs3)

    assert_equal Date.new(2012,12,12), results.period
    refute results.successful?
    assert_equal 3, results.providers_count
    assert_equal 1, results.providers_failed_count
    assert_equal 5, results.buyers_failed_count
  end
end
