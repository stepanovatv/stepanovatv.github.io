FROM jekyll/jekyll

WORKDIR /stepanovatv.github.io 
COPY . /stepanovatv.github.io
RUN pwd  && ls -lah && bundle update && bundle
EXPOSE 4000/tcp
CMD bundle exec jekyll serve -w
