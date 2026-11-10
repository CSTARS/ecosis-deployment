FROM ubuntu:latest

# Install cron and any other packages you need
RUN apt-get update && apt-get install -y cron

# Add your script file
ADD ./tmp-cleanup.sh /tmp-cleanup.sh

# Add your cron job file to the cron directory
ADD cronjob /etc/cron.d/cronjob

# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/cronjob

# Apply cron job
RUN crontab /etc/cron.d/cronjob

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# Run the command on container startup
CMD cron && tail -f /var/log/cron.log