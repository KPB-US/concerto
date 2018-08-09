# to build for production:  docker build -t concerto .
# to build for staging:     docker build -t concerto --build-arg RAILS_ENV=staging .
FROM phusion/passenger-ruby23
ARG RAILS_ENV
ENV RAILS_ENV=${RAILS_ENV:-production}
RUN echo "environment: $RAILS_ENV"
LABEL maintainer="Concerto Authors \"team@concerto-signage.org\""

ENV HOME /home/app

CMD ["/sbin/my_init"]

# additional software, some required by various gems
RUN add-apt-repository "deb http://us.archive.ubuntu.com/ubuntu/ trusty universe"
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -yqq libreoffice build-essential git-core imagemagick nodejs ruby-rmagick libpq5 sudo tzdata \
  zlib1g-dev libmagickcore-dev libmagickwand-dev libsqlite3-dev libmysqlclient-dev libpq-dev libxslt-dev libssl-dev

# set up the application
WORKDIR /home/app/concerto
#RUN mkdir -p /home/app/concerto/log
#COPY --chown=app:app . /home/app/concerto
#RUN rm /home/app/concerto/db/*.sqlite3
RUN git clone https://github.com/concerto/concerto .
RUN chown -R app:app /home/app/concerto

RUN gem install bundler
RUN sudo -u app --login sh -c "echo RAILS_ENV=$RAILS_ENV; cd concerto; RAILS_ENV=$RAILS_ENV bundle install --deployment --without=postgres"
#RUN sudo -u app --login sh -c "cd concerto; RAILS_ENV=$RAILS_ENV bundle update parser"
RUN sudo -u app --login sh -c "cd concerto; RAILS_ENV=$RAILS_ENV bundle exec rake assets:precompile"
RUN sudo -u app --login sh -c "cd concerto; RAILS_ENV=$RAILS_ENV bundle exec rake db:seed"

# set up the service
RUN echo "USERNAME=app" >/etc/default/concerto
RUN echo "CONCERTODIR=/home/app/concerto" >>/etc/default/concerto
RUN echo "RAILS_ENVIRONMENT=$RAILS_ENV" >>/etc/default/concerto
RUN cp /home/app/concerto/concerto-init.d /etc/init.d/concerto && chmod u+x /etc/init.d/concerto
RUN update-rc.d concerto defaults
RUN echo "service concerto start" >/etc/my_init.d/90_concerto.sh && chmod +x /etc/my_init.d/90_concerto.sh

# set up nginx
EXPOSE 80
RUN rm -f /etc/service/nginx/down
RUN rm /etc/nginx/sites-enabled/default
RUN sed -e "s/production/$RAILS_ENV/g" tools/nginx.docker.conf > /etc/nginx/sites-enabled/concerto.conf

# set up logrotation
RUN sed -e 's/\/usr\/share\//\/home\/app\//g' tools/concerto.logrotate >/etc/logrotate.d/concerto

# clean up
WORKDIR /tmp
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# If you want any data in the containers created from this image to persist betweeen invocations then
# you must list the directories here, and create volumes in docker for them and specify them when you
# create the container.  If they are only listed here, then they use new local volumes each time.
# To create a volume:  docker volume create concertodb
# To specify for the container to use:  docker run --rm -p 4000:80 --mount 'type=volume,src=haconcerto,dst=/home/app/concerto' concerto 
VOLUME ["/home/app/concerto"]
