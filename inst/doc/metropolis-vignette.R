## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(echo = TRUE)

## ----data---------------------------------------------------------------------
y = c(rep(1, 36), rep(0, 198)) # leukemia cases
x = c(rep(1, 3), rep(0, 33), rep(1, 5), rep(0, 193)) # exposure

## ----Helper functions---------------------------------------------------------
#helper functions
expit <- function(mu) 1/(1+exp(-mu))

loglik = function(y,x,beta){
  # calculate the log likelihood
  lli = dbinom(y, 1, expit(beta[1] + x*beta[2]), log=TRUE)
  sum(lli)
}

riskdifference = function(y,x,beta){
  # baseline odds (offset)
  # calculate a risk difference
  poprisk = 4.8/100000
  popodds = poprisk/(1-poprisk)
  studyodds = mean(y)/(1-mean(y))
  r1 = expit(log(popodds/studyodds) + beta[1] + beta[2])
  r0 = expit(log(popodds/studyodds) + beta[1])
  mean(r1-r0)
}

## ----mle, echo=TRUE, results="hold"-------------------------------------------
data = data.frame(leuk=y, magfield=x)
mod = glm(leuk ~ magfield, family=binomial(), data=data)
summary(mod)$coefficients

beta1 = summary(mod)$coefficients[2,1]
se1 = summary(mod)$coefficients[2,2]
cat("\n\nMaximum likelihood beta coefficient (95% CI)\n")
round(c(beta=beta1, ll=beta1+se1*qnorm(0.025), ul=beta1+se1*qnorm(0.975)), 2)

cat("\n\nMaximum likelihood odds ratio (95% CI)\n")
round(exp(c(beta=beta1, ll=beta1+se1*qnorm(0.025), ul=beta1+se1*qnorm(0.975))), 2)

cat("\n\nMaximum likelihood risk difference (multiplied by 1000) \n")
round(c(rd_1000=riskdifference(y,x,mod$coefficients)*1000), 2)


## ----random walk metropolis---------------------------------------------------
# initialize
M=10000
set.seed(91828)
beta_post = matrix(nrow=M, ncol=2)
colnames(beta_post) = c('beta0', 'beta1')
accept = numeric(M)
rd = numeric(M)
beta_post[1,] = c(2,-3)
rd[1] = riskdifference(y,x,beta_post[1,])
accept[1] = 1
for(i in 2:M){
  oldb = beta_post[i-1,]
  prop = rnorm(2, sd=0.2)
  newb = oldb+prop
  num = loglik(y,x,newb)
  den = loglik(y,x,oldb)
  acceptprob = exp(num-den)
  acc = (acceptprob > runif(1))
  if(acc){
    beta_post[i,] = newb 
    accept[i] = 1
  }else{
    beta_post[i,] = oldb 
    accept[i] = 0
  }
  rd[i] = 1000*riskdifference(y,x,beta_post[i,])
}


## ----Inspecting, fig.width =5, fig.height =6----------------------------------
mean(accept)
summary(beta_post)
init = beta_post[1,]
postmean = apply(beta_post[-c(1:1000),], 2, mean)
cat("Posterior mean\n")
round(postmean, 2)

plot(beta_post, pch=19, col=rgb(0,0,0,0.05), xlab=expression(beta[0]), ylab=expression(beta[1]), xlim=c(-2.5,2.5), ylim=c(-4.5,4.5))
points(init[1], init[2], col="red", pch=19)
points(postmean[1], postmean[2], col="orange", pch=19)
legend("topright", col=c("red", "orange"), legend=c("Initial value", "Post. mean"), pch=19)

plot(beta_post[,2], type='l',  ylab=expression(beta[1]), xlab="Iteration", ylim=c(-4, 4))
plot(rd, type='l',  ylab="RD*1000", xlab="Iteration", ylim=c(-4, 4))

plot(density(beta_post[-c(1:1000),2]), xlab=expression(beta[1]), ylab="Density", main="")
plot(density(rd[-c(1:1000)]), xlab="RD*1000", ylab="Density", main="")

## ----guided metropolis--------------------------------------------------------
# initialize
M=10000
set.seed(91828)
beta_post_guide = matrix(nrow=M, ncol=2)
colnames(beta_post_guide) = c('beta0', 'beta1')
accept = numeric(M)
rd_guide = numeric(M)
beta_post_guide[1,] = c(2,-3)
rd_guide[1] = riskdifference(y,x,beta_post_guide[1,])
accept[1] = 1
dir = 1
for(i in 2:M){
  oldb = beta_post_guide[i-1,]
  prop = dir*abs(rnorm(2, sd=0.2))
  newb = oldb+prop
  num = loglik(y,x,newb)
  den = loglik(y,x,oldb)
  acceptprob = exp(num-den)
  acc = (acceptprob > runif(1))
  if(acc){
    beta_post_guide[i,] = newb 
    accept[i] = 1
  }else{
    beta_post_guide[i,] = oldb 
    accept[i] = 0
    dir = dir*-1
  }
  rd_guide[i] = 1000*riskdifference(y,x,beta_post_guide[i,])
}

postmean = apply(beta_post_guide[-c(1:1000),], 2, mean)
cat("Posterior mean, guided\n")
round(postmean, 2)


## ----Comparing guided, fig.width =8, fig.height =5----------------------------
col1 = rgb(0,0,0,.5)
col2 = rgb(1,0,0,.35)
par(mfcol=c(1,2))

#trace plots
plot(beta_post[1:200,2], type='l',  ylab=expression(beta[1]), xlab="Iteration", ylim=c(-4, 4), col=col1)
lines(beta_post_guide[1:200,2], col=col2)
legend("topright", lty=1, col=c(col1, col2), legend=c("Rand. walk", "Guided"))
plot(9800:10000, beta_post[9800:10000,2], type='l',  ylab=expression(beta[1]), xlab="Iteration", ylim=c(-4, 4), col=col1)
lines(9800:10000, beta_post_guide[9800:10000,2], col=col2)
legend("topright", lty=1, col=c(col1, col2), legend=c("Rand. walk", "Guided"))

# density plots
plot(density(beta_post_guide[-c(1:1000),2]), col=col2, xlab=expression(beta[1]), ylab="Density", main="")
lines(density(beta_post[-c(1:1000),2]), col=col1)
legend("bottomright", lty=1, col=c(col1, col2), legend=c("Rand. walk", "Guided"))


plot(density(rd_guide[-c(1:1000)]), xlab="RD*1000", ylab="Density", main="", col=col2)
lines(density(rd[-c(1:1000)]), col=col1)
legend("topright", lty=1, col=c(col1, col2), legend=c("Rand. walk", "Guided"))
par(mfcol=c(1,1))

## ----guided and adaptive metropolis-------------------------------------------
# initialize
M=10000
burnin=1000
set.seed(91828)
beta_post_adaptguide = matrix(nrow=M+burnin, ncol=2)
colnames(beta_post_adaptguide) = c('beta0', 'beta1')
accept = numeric(M+burnin)
rd_adaptguide = numeric(M+burnin)
beta_post_adaptguide[1,] = c(2,-3)
rd_adaptguide[1] = riskdifference(y,x,beta_post[1,])
accept[1] = 1
prop.sigma = c(0.2, 0.2)
dir = 1
for(i in 2:(M+burnin)){
  if((i < burnin) & (i > 25)){
    prop.sigma = apply(beta_post_adaptguide[max(1, i-100):(i-1),], 2, sd)
  }
  oldb = beta_post_adaptguide[i-1,]
  prop = dir*abs(rnorm(2, sd=prop.sigma))
  newb = oldb+prop
  num = loglik(y,x,newb)
  den = loglik(y,x,oldb)
  acceptprob = exp(num-den)
  acc = (acceptprob > runif(1))
  if(acc){
    beta_post_adaptguide[i,] = newb 
    accept[i] = 1
  }else{
    beta_post_adaptguide[i,] = oldb 
    accept[i] = 0
    dir = dir*-1
  }
  rd_adaptguide[i] = 1000*riskdifference(y,x,beta_post_adaptguide[i,])
}
postmean = apply(beta_post_adaptguide[-c(1:1000),], 2, mean)
cat("Posterior mean, guided and adaptive\n")
round(postmean, 2)


## ----Comparing 2, fig.width =8, fig.height =5---------------------------------
col1 = rgb(0,0,0,.5)
col2 = rgb(1,0,0,.35)
par(mfcol=c(1,2))

#trace plots
plot(beta_post[1:200,2], type='l',  ylab=expression(beta[1]), xlab="Iteration", ylim=c(-4, 4), col=col1)
lines(beta_post_adaptguide[1:200,2], col=col2)
legend("topright", lty=1, col=c(col1, col2), legend=c("Rand. walk", "Guided, adaptive"))
plot(9800:10000, beta_post[9800:10000,2], type='l',  ylab=expression(beta[1]), xlab="Iteration", ylim=c(-4, 4), col=col1)
lines(9800:10000, beta_post_adaptguide[9800:10000,2], col=col2)
legend("topright", lty=1, col=c(col1, col2), legend=c("Rand. walk", "Guided, adaptive"))

# density plots
plot(density(beta_post_adaptguide[-c(1:1000),2]), col=col2, xlab=expression(beta[1]), ylab="Density", main="")
lines(density(beta_post[-c(1:1000),2]), col=col1)
legend("bottomright", lty=1, col=c(col1, col2), legend=c("Rand. walk", "Guided, adaptive"))


plot(density(rd_adaptguide[-c(1:1000)]), xlab="RD*1000", ylab="Density", main="", col=col2)
lines(density(rd[-c(1:1000)]), col=col1)
legend("topright", lty=1, col=c(col1, col2), legend=c("Rand. walk", "Guided, adaptive"))
par(mfcol=c(1,1))

## ----guided and adaptive metropolis using normal priors-----------------------
# initialize
M=10000
burnin=1000
set.seed(91828)
beta_post_adaptguide2 = matrix(nrow=M+burnin, ncol=2)
colnames(beta_post_adaptguide2) = c('beta0', 'beta1')
accept = numeric(M+burnin)
rd_adaptguide2 = numeric(M+burnin)
beta_post_adaptguide2[1,] = c(2,-3)
rd_adaptguide2[1] = riskdifference(y,x,beta_post[1,])
accept[1] = 1
prop.sigma = c(0.2, 0.2)
dir = 1
for(i in 2:(M+burnin)){
  if((i < burnin) & (i > 25)){
    prop.sigma = apply(beta_post_adaptguide2[max(1, i-100):(i-1),], 2, sd)
  }
  oldb = beta_post_adaptguide2[i-1,]
  prop = dir*abs(rnorm(2, sd=prop.sigma))
  newb = oldb+prop
  num = loglik(y,x,newb) + dnorm(newb[1], mean=0, sd=sqrt(100), log=TRUE) + dnorm(newb[2], mean=0, sd=sqrt(0.5), log=TRUE)
  den = loglik(y,x,oldb) + dnorm(oldb[1], mean=0, sd=sqrt(100), log=TRUE) + dnorm(oldb[2], mean=0, sd=sqrt(0.5), log=TRUE)
  acceptprob = exp(num-den)
  acc = (acceptprob > runif(1))
  if(acc){
    beta_post_adaptguide2[i,] = newb 
    accept[i] = 1
  }else{
    beta_post_adaptguide2[i,] = oldb 
    accept[i] = 0
    dir = dir*-1
  }
  rd_adaptguide2[i] = 1000*riskdifference(y,x,beta_post_adaptguide2[i,])
}
postmean = apply(beta_post_adaptguide2[-c(1:1000),], 2, mean)
cat("Posterior mean, guided and adaptive\n")
round(postmean, 2)


## ----Inspecting output with normal priors, fig.width =8, fig.height =5--------
mean(accept)
init = beta_post_adaptguide[1,]
postmean = apply(beta_post_adaptguide[-c(1:1000),], 2, mean)
cat("Posterior mean, uniform priors\n")
round(postmean, 2)

init2 = beta_post_adaptguide2[1,]
postmean2 = apply(beta_post_adaptguide2[-c(1:1000),], 2, mean)
cat("Posterior mean, informative normal priors\n")
round(postmean2, 2)


par(mfcol=c(1,2))
plot(beta_post_adaptguide, pch=19, col=rgb(0,0,0,0.05), xlab=expression(beta[0]), ylab=expression(beta[1]), xlim=c(-2.5,2.5), ylim=c(-4.5,4.5), main="Uniform priors")
points(init[1], init[2], col="red", pch=19)
points(postmean[1], postmean[2], col="orange", pch=19)
legend("topright", col=c("red", "orange"), legend=c("Initial value", "Post. mean"), pch=19)

plot(beta_post_adaptguide2, pch=19, col=rgb(0,0,0,0.05), xlab=expression(beta[0]), ylab=expression(beta[1]), xlim=c(-2.5,2.5), ylim=c(-4.5,4.5), main="Informative priors")
points(init2[1], init2[2], col="red", pch=19)
points(postmean2[1], postmean2[2], col="orange", pch=19)
legend("topright", col=c("red", "orange"), legend=c("Initial value", "Post. mean"), pch=19)

par(mfcol=c(1,2))
plot(beta_post_adaptguide[,2], type='l',  ylab=expression(beta[1]), xlab="Iteration", ylim=c(-4, 4))
plot(beta_post_adaptguide2[,2], type='l',  ylab=expression(beta[1]), xlab="Iteration", ylim=c(-4, 4))

plot(density(beta_post_adaptguide[-c(1:1000),2]), xlab=expression(beta[1]), ylab="Density", main="", xlim=c(-4, 4))
plot(density(beta_post_adaptguide2[-c(1:1000), 2]), xlab=expression(beta[1]), ylab="Density", main="", xlim=c(-4, 4))
par(mfcol=c(2,1))

plot(rd_adaptguide, type='l',  ylab="RD*1000", xlab="Iteration", ylim=c(-.2, .5))
plot(rd_adaptguide2, type='l',  ylab="RD*1000", xlab="Iteration", ylim=c(-.2, .5))

plot(density(rd_adaptguide[-c(1:1000)]), xlab=expression(beta[1]), ylab="Density", main="", xlim=c(-.2, .5))
plot(density(rd_adaptguide2[-c(1:1000)]), xlab="RD*1000", ylab="Density", main="", xlim=c(-.2, .5))
par(mfcol=c(1,1))

## ----Using the R package, fig.width =8, fig.height =5-------------------------
library(metropolis)
data("magfields", package="metropolis")

# random walk
res.rw = metropolis_glm(y ~ x, data=magfields, family=binomial(), iter=20000, burnin=3000, adapt=FALSE, guided=FALSE, block=TRUE, inits=c(2,-3), control = metropolis.control(prop.sigma.start = c(0.05, .1)))

summary(res.rw, keepburn = FALSE)

plot(res.rw, par = 1:2, keepburn=TRUE)

# guided, adaptive
res.ga = metropolis_glm(y ~ x, data=magfields, family=binomial(), iter=20000, burnin=3000, adapt=TRUE, guided=TRUE, block=FALSE, inits=c(2,-3))

summary(res.ga, keepburn = FALSE)

plot(res.ga, par = 1:2, keepburn=TRUE)


## ----Initial values, fig.width =8, fig.height =5------------------------------
# guided, adaptive
res.ga.init = metropolis_glm(y ~ x, data=magfields, family=binomial(), iter=20000, burnin=1000, adapt=TRUE, guided=TRUE, block=FALSE, inits="glm")

summary(res.ga.init, keepburn = FALSE)

plot(res.ga.init, par = 1:2, keepburn=TRUE)


## ----Risk difference after glm_metropolis, fig.width =8, fig.height =5--------
# guided, adaptive
beta = as.matrix(res.ga.init$parms[, c("b_0", "b_1")])

y = magfields$y
X = cbind(rep(1, dim(magfields)[1]), magfields$x)

1000*riskdifference(y,X,beta[1,])

# calculate risk difference for every value of model coefficients
rd.ga.init = apply(beta, 1, function(b) 1000*riskdifference(y,X,b))

par(mfcol=c(2,1))
 plot(density(rd.ga.init), xlab = "RD*1000", ylab="Kernel density", main="", xlim=c(-.2, 2.5))
 plot(rd.ga.init, type='l', xlab = "RD*1000", ylab="Iteration", ylim=c(-.2, 2.5))
par(mfcol=c(1,1))

# posterior mean, median, credible intervals
mean(rd.ga.init[-c(1:1000)])
quantile(rd.ga.init[-c(1:1000)], p = c(.5, .025, .975) )


