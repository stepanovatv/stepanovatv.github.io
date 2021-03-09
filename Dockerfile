FROM jekyll/jekyll

WORKDIR /stepanovatv.github.io 
CMD bundle update && bundle 
