def handler(event, context):
    order = event.get("order")

    if not order:
        raise ValueError("Missing 'order' in input")

    order["inventory_status"] = "RESERVED"

    return order