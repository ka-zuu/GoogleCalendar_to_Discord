from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

import datetime
import sys

def main():
    if len(sys.argv) < 2:
        print("Please provide a calendar ID as a command line argument.")
        return
    calendar_id = sys.argv[1]

    creds = Credentials.from_service_account_file('credentials.json', scopes=['https://www.googleapis.com/auth/calendar.events'])

    try:
        service = build('calendar', 'v3', credentials=creds)
        today = datetime.datetime.now().replace(hour=0, minute=0, second=0, microsecond=0).isoformat() + '+09:00'
        events_result = service.events().list(calendarId=calendar_id, timeMin=today, singleEvents=True, orderBy='startTime').execute()
        events = events_result.get('items', [])

        if not events:
            print('No upcoming events found.')
        for event in events:
            start = event['start'].get('dateTime', event['start'].get('date'))
            print(start, event['summary'])

    except HttpError as error:
        print('An error occurred: %s' % error)

if __name__ == '__main__':
    main()