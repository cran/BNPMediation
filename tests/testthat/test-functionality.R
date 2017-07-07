context("functionality")

test_that("test are here", {
  expect_equal(2 * 2, 4)
})


test_that("test that output is of correct type",
        { expect_type(bnpmediation(data_treatment, data_control, prior = prior, mcmc = mcmc, state = state), "list")
})


#           expect_type(bnpconmediation(data_treatment, data_control,prior, mcmc, state, status=TRUE,na.action, q=2, NN=10, n1=10, n0=10, extra.thin=0, cond.values=c(45,35), col.values=c(1,2))), "list")
