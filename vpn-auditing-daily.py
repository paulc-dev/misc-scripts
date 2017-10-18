#!/usr/bin/python
# This script checks the OpenVPN log file for all login successes and failures
# during the course of a day, then emails a report.
# The /var/log/openvpnas.log file is where vpn events are logged
import re
import datetime
import smtplib
from email.MIMEMultipart import MIMEMultipart
from email.MIMEBase import MIMEBase
from email.MIMEText import MIMEText
from email import Encoders

today = datetime.datetime.now() - datetime.timedelta(days=1)
todays_date = today.strftime('%Y-%m-%d')


search_term = todays_date
vpn_log = open('/var/log/openvpnas.log')

uname_start = "(user=\'"
uname_end = "\')"

success_start = "\'user\': \'"
success_end = "\'"

logon_success_list = []
logon_failure_list = []

# The log file is searched for all events happening during the past day,
# and if and event is found matching the date, then it checks if it
# indicates a login success or failure event.
# Each time a matching event is found, the login_success or login_failure
# lists will be populated
for line in vpn_log:
   line = line.rstrip()
   if re.search(todays_date, line) and re.search ('AUTH SUCCESS', line):
      line_substr = line[line.index(success_start) + len(success_start):len(line)]
      uname = line_substr[0:line_substr.index(success_end)]
      logon_time = line[0:19]
      logon_success = (logon_time, uname, "Logon Success")
      logon_success_list.append(logon_success)
   if re.search(todays_date, line) and re.search ('LDAP exception', line):
      line_substr = line[line.index(uname_start) + len(uname_start):len(line)]
      uname = line_substr[0:line_substr.index(uname_end)]
      logon_time = line[0:19]
      logon_failure = (logon_time, uname, "Invalid username")
      logon_failure_list.append(logon_failure)
   if re.search(todays_date, line) and re.search ('LDAP invalid credentials', line):
      line_substr = line[line.index(uname_start) + len(uname_start):len(line)]
      uname = line_substr[0:line_substr.index(uname_end)]
      logon_time = line[0:19]
      logon_failure = (logon_time, uname, "Invalid credentials")
      logon_failure_list.append(logon_failure)

blueHeading = '<span style="color:#0B173B">'
blueHeadingEnd = '</span>'
blueText = '<span style="color:#0000FF">'
blueTextEnd = '</span>'

greenHeading = '<span style="color:#0B610B">'
greenHeadingEnd = '</span>'
greenText = '<span style="color:#088A08">'
greenTextEnd = '</span>'

redHeading = '<span style="color:#610B0B">'
redHeadingEnd = '</span>'
redText = '<span style="color:#DF0101">'
redTextEnd = '</span>'

orangeHeading = '<span style="color:#8A4B08">'
orangeHeadingEnd = '</span>'
orangeText = '<span style="color:#FF8000">'
orangeTextEnd = '</span>'

# Here the text of the email notification is generated
emailBody = "<html><head></head><body><h2>OpenVPN Login Auditing Daily Notification</h2>\n"
emailBody += "<h3>Login Summary for: " + todays_date + "</h3>\n"

nextSuccessColor = 1
nextFailureColor = 1

emailBody += "<pre>------------------------------------------------</pre>\n"
emailBody += "<pre>" + blueHeading + "<b>Successful VPN Logins:</b>" + blueHeadingEnd + "</pre>\n"


for x in logon_success_list:
   if nextSuccessColor == 1:
      emailBody += "<pre>  " + blueText + "Username: " + x[1] + blueTextEnd + "</pre>\n"
      emailBody += "<pre>  " + blueText + "Message: " + x[2] + blueTextEnd + "</pre>\n"
      emailBody += "<pre>  " + blueText + "Timestamp: " + x[0] + blueTextEnd +"</pre><br>\n"
      nextSuccessColor = 2
   else:
      emailBody += "<pre>  " + greenText + "Username: " + x[1] + greenTextEnd + "</pre>\n"
      emailBody += "<pre>  " + greenText + "Message: " + x[2] + greenTextEnd + "</pre>\n"
      emailBody += "<pre>  " + greenText + "Timestamp: " + x[0] + greenTextEnd +"</pre><br>\n"
      nextSuccessColor = 1


emailBody += "<pre>------------------------------------------------</pre>\n"
emailBody += "<pre>" + redHeading + "<b>VPN Logins Failures:</b>" + redHeadingEnd + "</pre>\n"
for y in logon_failure_list:
   if nextFailureColor == 1:
      emailBody += "<pre>  " + redText + "Username: " + y[1] + redTextEnd + "</pre>\n"
      emailBody += "<pre>  " + redText + "Message: " + y[2] + redTextEnd + "</pre>\n"
      emailBody += "<pre>  " + redText + "Timestamp: " + y[0] + redTextEnd +"</pre><br>\n"
      nextFailureColor = 2
   else:
      emailBody += "<pre>  " + orangeText + "Username: " + y[1] + orangeTextEnd + "</pre>\n"
      emailBody += "<pre>  " + orangeText + "Message: " + y[2] + orangeTextEnd + "</pre>\n"
      emailBody += "<pre>  " + orangeText + "Timestamp: " + y[0] + orangeTextEnd +"</pre><br>\n"
      nextFailureColor = 1

SMTP_PORT = 25
print emailBody

MAIL_SERVER='hostname.example.com'
SENDER_EMAIL = 'LoginAuditing@exampe.com'
SENDER_USER = 'LoginAuditing'
SENDER_PASSWORD = 'password'
TO_EMAIL = ['jdoe@example.com']

msg = MIMEMultipart()

msg['From'] = 'LoginAuditing@example.com'
msg['To'] = " , ".join(TO_EMAIL)
msg['Subject'] = 'Open VPN Login Daily Notification'

msgText = MIMEText(emailBody, 'html')
msg.attach(msgText)

mail_server = smtplib.SMTP(MAIL_SERVER)
mail_server.ehlo()
mail_server.login(SENDER_USER, SENDER_PASSWORD)
mail_server.sendmail(SENDER_EMAIL, TO_EMAIL, msg.as_string())
mail_server.close()