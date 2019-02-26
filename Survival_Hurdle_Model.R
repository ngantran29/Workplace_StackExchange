# Users newly joined the forum in the last 6 months were excluded from the analysis
UserDataframe <- filter(UserDataframe, CreationDate < "2017-06-01T00:00:00")

# User accounts created in the latest 6 months was excluded from analysis
UserDataframe$active_time = difftime(UserDataframe$LastAccessDate, UserDataframe$CreationDate, tz = "UTC", units = "days")
UserDataframe$active_time = as.numeric(UserDataframe$active_time, units="days")

# Collect all posts by the account Id and calculate mean Favorite and Comment count
user_regression <- merge(UserDataframe,PostDataframe, by.x = "AccountId", by.y = "OwnerUserId", all = T)
user_regression <- filter(user_regression, PostTypeId == 1|PostTypeId == 2)
user_regression <- group_by(user_regression, AccountId)
user_regression <- mutate(user_regression,
                          mean_FavoriteCount = mean(FavoriteCount), mean_ReplyCount = mean(ReplyCount))
user_regression <- user_regression[!duplicated(user_regression$AccountId),]

# Collect all posts which reply to the account Id and calculate mean sentiment
user_regression2 <- merge(UserDataframe, sentiment_regression, by.x = "AccountId", by.y = "OwnerUserId.x", all = T)
user_regression2 <- group_by(user_regression2, AccountId)
user_regression2 <- mutate(user_regression2,
                           mean_sentiment_receive = mean(Bing.y))
user_regression2 <- user_regression2[!duplicated(user_regression2$AccountId),]
user_regression2 <- data.frame(user_regression2$AccountId, user_regression2$mean_sentiment_receive)

# Combine into data frame

user_regression <- merge(user_regression,user_regression2, by.x = "AccountId", by.y = "user_regression2.AccountId", all = T)
user_regression <- filter(user_regression, !is.na(active_time))
user_regression$user_regression2.mean_sentiment_receive[sapply(user_regression$user_regression2.mean_sentiment_receive, is.na)] <- 0
user_regression$active_year = user_regression$active_time/365

#### Distribution
## Histogram shows positive skew

hist(user_regression$active_year)
qqnorm(user_regression$active_year)
summary(user_regression$active_year)

install.packages(c("survival", "survminer"))
library("survival")
library("survminer")

## Create right sensoring date
max(LastAccessDate)

### choose 6 months before the last recorded date "2017-12-03 03:35:46 UTC" as the right censoring date

user_regression$status <- ifelse(user_regression$LastAccessDate < "2017-06-01 00:00:00 UTC", 1,0)

### create categories of sentiment received including: strong negative, weak negative, neutral, weal positive and strong positive
user_regression$type <- ifelse(user_regression$user_regression2.mean_sentiment_receive == 0, "neutral", 
                               ifelse(user_regression$user_regression2.mean_sentiment_receive <= -7, " strongly negative", 
                                      ifelse(user_regression$user_regression2.mean_sentiment_receive > -7 & 
                                               user_regression$user_regression2.mean_sentiment_receive < 0, " weakly negative", 
                                             ifelse(user_regression$user_regression2.mean_sentiment_receive < 7 & 
                                                      user_regression$user_regression2.mean_sentiment_receive > 0, " weakly positive", "strongly positive")
                                      )))

user_regression$type <- as.factor(user_regression$type)
# Choose 'neutral' as the standardized group
user_regression$type <- relevel(user_regression$type, ref = "neutral")

### fit data into Cox proportional hazards regression model and creat survival plot
cox_user <- with(user_regression, Surv(active_year,status))

cox_user_fit <- survfit(cox_user~type, data=user_regression)

ggsurvplot(cox_user_fit, risk.table = T, pval = T, palette = "Set2")

coxph_user_post <- coxph(Surv(active_year,status) ~ factor(type), 
                         data = user_regression)
summary(coxph_user_post)

# Calculate number of post each user by group using user Id, arrange, create count and filter only the biggest count number
# Post without

number_post <- allposts %>% 
  group_by(OwnerUserId) %>% arrange(OwnerUserId)

number_post <- number_post %>% 
  group_by(OwnerUserId) %>% 
  mutate(postcount = 1:n())

number_post <- number_post %>% 
  group_by(OwnerUserId) %>%
  filter(postcount == max(postcount))

# Match number of posts with user using user Id 
user_post_regression <- merge(user_regression, number_post, by.x = "AccountId", by.y = "OwnerUserId")

#### Distribution
## Test for Poisson Distribution Dependent variable
class(user_post_regression$postcount) <- "numeric"
hist(user_post_regression$postcount)
qqnorm(user_post_regression$postcount)
sd(user_post_regression$postcount)

## Remove users who only log in their accounts once which mean active_time = 0
## change too long column name
user_post_regression <- filter(user_post_regression, user_post_regression$active_year != 0)
which( colnames(user_post_regression)=="user_regression2.mean_sentiment_receive" )
names(user_post_regression)[17]<-"mean_sentiment_receive"

#### Poisson regression

glm_post <- glm(postcount ~ mean_FavoriteCount + mean_ReplyCount + mean_sentiment_receive, data=user_post_regression, family = "poisson")
summary(glm_post)

#### Dispersion test
install.packages("AER")
library(AER)

dispersiontest(glm_post)

#### Negative binomial regression hurdle model
install.packages("pscl")
library(pscl)

glmbn_hurdle <- hurdle(postcount - 1 ~ mean_FavoriteCount + mean_ReplyCount + mean_sentiment_receive, data=user_post_regression, dist = "negbin")
summary(glmbn_hurdle)

#### calculate VIF
library(car)
vif(glmbn_post0fl)