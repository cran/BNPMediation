#' Posterior Means and 95\% C.I.s of the NIE, NDE and TE
#'
#' Obtain posterior means and credible intervals of the effects.
#' @param dataTreatment The observed data under Z=1
#' @param dataControl The observed data under Z=0
#' @param prior a list giving the prior information
#' @param mcmc a list giving the MCMC parameters
#' @param state a list giving the current value of the parameters
#' @param status a logical variable indicating whether this run is new (TRUE) or the continuation of a previous analysis (FALSE)
#' @param na.action a function that indicates what should happen when the data contain NAs
#' @param q A dimension of the observed data, i.e., number of covariates plus 2
#' @param NN Number of samples drawn for each iteration from the joint distribution of the mediator and the covariates. Default is 10
#' @param n1 Number of observations under Z=1
#' @param n0 Number of observations under Z=0
#' @param extra.thin Giving the extra thinning interval
#' @param seed Value to be given to the seed
#' @return ENIE Posterior mean of the Natural Indirect Effect (NIE)
#' @return ENDE Posterior mean of the Natural Direct Effect (NDE)
#' @return ETE Posterior mean of the Total Effect (TE)
#' @return IE.c.i 95\% C.I. of the NIE
#' @return DE.c.i 95\% C.I. of the NDE
#' @return TE.c.i 95\% C.I. of the TE
#' @return Y11 Posterior samples of Y11
#' @return Y00 Posterior samples of Y00
#' @return Y10 Posterior samples of Y10
#'
#' @importFrom mnormt rmnorm dmnorm
#' @importFrom stats dnorm rnorm na.omit
#' @importFrom utils setTxtProgressBar txtProgressBar
#' @import DPpackage


#' @export
bnpmediation<-function(dataTreatment, dataControl, prior, mcmc, state, status=TRUE,na.action, q=2, NN=10, n1=10, n0=10, extra.thin=0, seed=12345)

{
  cat("***** Fitting observed data models via DPpackage::DPdensity()\n")
  obj1 = DPdensity(y=dataTreatment,prior=prior,mcmc=mcmc,state=state,status=TRUE, na.action=na.omit)
  obj0 = DPdensity(y=dataControl,prior=prior,mcmc=mcmc,state=state,status=TRUE, na.action=na.omit)

  cat("***** Running bnpmediation\n")

  obj1.dim <- dim(obj1$save.state$randsave)[2]-(q*(q+1)/2+2*q-1)
  obj0.dim <- dim(obj0$save.state$randsave)[2]-(q*(q+1)/2+2*q-1)

  Len.MCMC <- 1:dim(obj0$save.state$randsave)[1]
  if(extra.thin!=0){
    Len.MCMC <- Len.MCMC[seq(1, length(Len.MCMC), extra.thin)]
  }

  Ysamples<-OutSamples(obj1, obj0, q)
  Y11 <- Ysamples$Y1[Len.MCMC]
  Y00 <- Ysamples$Y0[Len.MCMC]

  set.seed(seed)

  mat.given.ij <- function(x, y) ifelse(x <= y, (q-1)*(x-1)+y-x*(x-1)/2, (q-1)*(y-1)+x-y*(y-1)/2)
  mat <- function(q) outer( 1:q, 1:q, mat.given.ij )

  pb <- txtProgressBar(min = 0, max = length(Len.MCMC), style = 3)

  Y10<-NULL

  index<-0
  for(j in Len.MCMC){
    index <- index + 1
    mu2 <- sapply(seq(2,obj0.dim, by=(q*(q+1)/2+q)), function(x)  obj0$save.state$randsave[j,x[1]:(x[1]+q-2)])
    sigma22 <- sapply(seq(q+q+1,obj0.dim, by=(q*(q+1)/2+q)), function(x)  obj0$save.state$randsave[j,x[1]:(x[1]+(q-1)*(q)/2-1)][mat(q-1)])
    if(q!=2){
      joint0 <- do.call("rbind", replicate(NN, data.frame(sapply(1:n0, function(x) rmnorm(1,mu2[,x],matrix(sigma22[,x],q-1,q-1,byrow=T) )))))
    }else{
      joint0 <- matrix(replicate(NN, sapply(1:n0, function(x) rnorm(1,mu2[x],sd=sqrt(sigma22[x]) )), simplify="array"), nrow=n0*NN)
    }
    unique.val <- unique(obj1$save.state$randsave[j,seq(1,obj1.dim,by=(q*(q+1)/2+q))])
    unique.ind <- NULL
    unique.prop <- NULL
    for(k in 1:length(unique.val)){
      unique.ind[k] <- which(obj1$save.state$randsave[j,seq(1,obj1.dim,by=(q*(q+1)/2+q))]==unique.val[k])[1]
      unique.prop[k] <- length(which(obj1$save.state$randsave[j,seq(1,obj1.dim,by=(q*(q+1)/2+q))]==unique.val[k]))/n1
    }
    b01 <- NULL
    Weight.num0 <- matrix(nrow=length(unique.val), ncol=n0*NN)
    B0 <- matrix(nrow=length(unique.val),ncol=n0*NN)

    t.ind<-0
    for(k in unique.ind){
      t.ind<-1+t.ind
      mu1<-obj1$save.state$randsave[j,(q*(q+1)/2+q)*k-(q*(q+1)/2+q)+1]
      mu2<-obj1$save.state$randsave[j,((q*(q+1)/2+q)*k-(q*(q+1)/2+q)+2):((q*(q+1)/2+q)*k-(q*(q+1)/2+q)+q)]
      sigma1<-obj1$save.state$randsave[j,(q*(q+1)/2+q)*k-(q*(q+1)/2+q)+q+1]
      sigma12<-obj1$save.state$randsave[j,(q*(q+1)/2+q)*k-(q*(q+1)/2+q)+((q+2):(2*q))]
      sigma22<-matrix(obj1$save.state$randsave[j,((q*(q+1)/2+q)*k-(q*(q+1)/2+q)+2*q+1):((q*(q+1)/2+q)*k)][mat(q-1)],q-1,q-1,byrow=TRUE)
      if(q!=2){
        Weight.num0[t.ind,1:(n0*NN)]<-unique.prop[t.ind]*dmnorm(joint0,mu2,sigma22)
      }else{
        Weight.num0[t.ind,1:(n0*NN)]<-unique.prop[t.ind]*dnorm(joint0,mu2,sd=sqrt(sigma22))
      }
      b01[t.ind]<-mu1-sigma12%*%solve(sigma22)%*%t(t(mu2))
      B0[t.ind,1:(n0*NN)]<-sigma12%*%solve(sigma22)%*%t(joint0)
    }
    Weight=apply(Weight.num0, 2, function(x) x/sum(x))
    test <- Weight*(b01+B0)
    Y10[index]<-mean(apply(test, 2, sum))
    Sys.sleep(0.05)
    setTxtProgressBar(pb, index)
  }

  z <- list(Y11=Y11,
            Y00=Y00,
            Y10=Y10,
            ENIE=mean(Y11-Y10),
            ENDE=mean(Y10-Y00),
            ETE=mean(Y11-Y00),
            TE.c.i=c(sort(Y11-Y00)[length(Len.MCMC)*0.025],sort(Y11-Y00)[length(Len.MCMC)*0.975]),
            IE.c.i=c(sort(Y11-Y10)[length(Len.MCMC)*0.025],sort(Y11-Y10)[length(Len.MCMC)*0.975]),
            DE.c.i=c(sort(Y10-Y00)[length(Len.MCMC)*0.025],sort(Y10-Y00)[length(Len.MCMC)*0.975]))
  z$call <- match.call()
  class(z) <- "bnpmediation"
  return(z)
}


