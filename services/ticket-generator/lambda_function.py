import json
import urllib.parse
import boto3
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Log the received event (for debugging in CloudWatch)
    logger.info("Received event: " + json.dumps(event, indent=2))

    # Get the object from the event
    # S3 events contain the bucket name and the file key (name)
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')

    try:
        logger.info(f"Processing new file upload: {key} from bucket: {bucket}")

        # SIMULATION: In a real app, we might use OpenCV to verify the ID or Pillow to stamp a watermark.
        # For this assignment, we will simulate "Verification" and "Ticket Generation".
        
        # 1. Read metadata (simulate size check)
        response = s3.head_object(Bucket=bucket, Key=key)
        file_size = response['ContentLength']
        
        if file_size > 5 * 1024 * 1024: # 5MB limit
            logger.warning(f"File {key} is too large ({file_size} bytes). Verification failed.")
            return {
                'statusCode': 400,
                'body': json.dumps('File too large')
            }

        # 2. Generate a "Ticket Receipt" text file
        ticket_id = key.split('.')[0] + "_TICKET.txt"
        ticket_content = f"""
        -----------------------------------
        OFFICIAL TICKET RECEIPT
        -----------------------------------
        Ticket ID: {ticket_id}
        Original Proof: {key}
        Status: VERIFIED
        Verification Timestamp: {context.aws_request_id}
        -----------------------------------
        """

        # 3. Upload the receipt back to the same bucket (in a 'tickets/' folder)
        # Note: To avoid infinite loops, we ensure we don't trigger on files inside 'tickets/' folder
        if not key.startswith("tickets/"):
            s3.put_object(
                Bucket=bucket,
                Key=f"tickets/{ticket_id}",
                Body=ticket_content
            )
            logger.info(f"Ticket generated successfully: tickets/{ticket_id}")

        return {
            'statusCode': 200,
            'body': json.dumps('Ticket Generation Complete')
        }

    except Exception as e:
        logger.error(e)
        print(e)
        raise e