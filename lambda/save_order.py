import os
import boto3
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
ORDERS_TABLE = os.environ["ORDERS_TABLE"]


def handler(event, context):
    order = event.get("order")

    if not order:
        raise ValueError("Missing 'order' in input")

    if order.get("payment_status") != "PAID":
        raise ValueError("Cannot save order: payment not completed")

    order["total_amount"] = Decimal(str(order["total_amount"]))

    table = dynamodb.Table(ORDERS_TABLE)
    table.put_item(Item=order)

    return order