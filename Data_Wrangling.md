Getting Data of the StackExchange Workplace Forum
================
Part 1. Parsing XML files and Attributes
========================================

The datadump of StackExchange family is publicly open for downloading, with relational XML files including posts, users, tags, etc information collected for the last 5 years.

``` r
library(XML)
# Define list of files and import list of XML documents
filePath <- list("Posts.xml", "Users.xml")
xmlFile <- sapply(filePath, xmlParse)
```

Each XML file contains many metadata as css attributes, a very common structure of interactive web. List of only relevant attributes is to be created and parse

``` r
# define list of relevant attributes and specific paths in each documents
attributePath <- list("//posts/row","//users/row")
attributeName <- list(list('Id','FavoriteCount','CommentCount','ViewCount','AnswerCount','Title','Body','CreationDate','OwnerUserId','ParentId','PostTypeId'), list('Id','CreationDate','LastAccessDate'))
```

The code was adapted for future use of new research using different information on the Forum. however, one weakness is the requirement to manually count number of cases.

``` r
# Create blank dataframe with Dimentions 
PostDataframe <- data.frame(matrix(NA, nrow = 72493, ncol = length(attributeName[[1]])))
colnames(PostDataframe) <- attributeName[[1]]
UserDataframe <- data.frame(matrix(NA, nrow = 55913, ncol = length(attributeName[[2]])))
colnames(UserDataframe) <- attributeName[[2]]      
# Define a function to fill the missing values with NA and create character vector
createVector <- function(listName){
  listName[sapply(listName, is.null)] <- NA
  listName = unlist(listName)
}
```

After that, we loop through two different loops: one with the list of XML files and another with the list of attributes in each file. Looping can be slow, but at least automatic ;)

``` r
# Loop over the list of all attributes in each document 
for(i in 1:length(attributePath)){
  for(j in 1:length(attributeName[[i]])){
    if(i == 1){
      attribute <- xpathSApply(xmlFile[[i]], attributePath[[i]], xmlGetAttr, attributeName[[i]][[j]])
      attribute <- createVector(attribute)
      PostDataframe[,j] <- attribute
    }else{
      attribute <- xpathSApply(xmlFile[[i]], attributePath[[i]], xmlGetAttr, attributeName[[i]][[j]])
      attribute <- createVector(attribute)
      UserDataframe[,j] <- attribute
    }
  }
}
```
Part 2. Cleaning Data for analysis
==================================

First step is to reformat all column to the correct format such as numeric or datetime

``` r
# format column with count value to numeric
class(PostDataframe[,2]) <- "numeric"
# format to date
PostDataframe[,10] <- as.POSIXct(PostDataframe[,10], format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
```

Eventhough R developers have been trying to promote the Stringr package for text processing, Regular Expressions is still a more universal choice especially when we have to switch among different programming languages.

Looking at some sample texts, many anomalies can be identified, including a lot of blockquotes, html and css markups and links.

``` r
library(rex)
#Remove Blockquote and the text inside
PostDataframe$Body <- gsub("<blockquote\\b[^<]*>[^<]*(?:<(?!/blockquote>)[^<]*)*</blockquote>", "", PostDataframe$Body, perl=T)
#Remove html and css markup
PostDataframe$Body <- gsub("<.*?>", "", PostDataframe$Body, perl=T)
PostDataframe$Body <- gsub("\n", "", PostDataframe$Body, perl=T)
#Remove links
PostDataframe$Body <- gsub("\\s?(f|ht)(tp)(s?)(://)([^\\.]*)[\\.|/](\\S*)", "", PostDataframe$Body, perl=T)
```

It's quite a tedious process! The good news is asically we've got two clean dataframes, one with all the posts and metadata and another with the users login information. Now we're ready for any cool analysis.
