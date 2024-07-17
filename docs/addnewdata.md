# Uploading New Sample Data

It is possibly to upload custom data to this solution with zero modifications if it is the same retail scenario. The solution has a products container which contains product information, and a customer container which contains a single document for customer profile and multiple salesOrder documents for each of their sales orders.

To upload new data, or to extend the solution to ingest your own data that will be processed by the Change Feed and then made available as a context for chat completions, it's recommended to use the approach highlighted in the [post-deployment data import script](../infra/aca/azd-hooks/postdeploy.ps1).

The steps below will guide you through the process of uploading new data to the Cosmos DB containers:

1. Prepare your data
    
    Ensure your data is in a JSON format. Ideally, you should have a single JSON file for each container you want to upload data to. The following item types are supported:
        
    - Products
    - Customers
    - SalesOrders
    
    For examples of supported item types, see the [Examples of supported item types](#examples-of-supported-item-types) section below.

2. Update the [post-deployment data import script](../infra/aca/azd-hooks/postdeploy.ps1) to match the names of your data files. Also, in case you have already completed the deployment, make sure to update the script with the correct API endpoint URL.

3. Check the Azure Cosmos DB containers to validate the data has been uploaded successfully.

## Examples of supported item types

Here is an example of a product item:

```json
{
  "id": "027D0B9A-F9D9-4C96-8213-C8546C4AAE71",
  "categoryId": "26C74104-40BC-4541-8EF5-9892F7F03D72",
  "categoryName": "Components, Saddles",
  "sku": "SE-R581",
  "name": "LL Road Seat/Saddle",
  "description": "The product called \"LL Road Seat/Saddle\"",
  "price": 27.12,
  "tags": [
    {
      "id": "0573D684-9140-4DEE-89AF-4E4A90E65666",
      "name": "Tag-113"
    },
    {
      "id": "6C2F05C8-1E61-4912-BE1A-C67A378429BB",
      "name": "Tag-5"
    },
    {
      "id": "B48D6572-67EB-4630-A1DB-AFD4AD7041C9",
      "name": "Tag-100"
    },
    {
      "id": "D70F215D-A8AC-483A-9ABD-4A008D2B72B2",
      "name": "Tag-85"
    },
    {
      "id": "DCF66D9A-E2BF-4C70-8AC1-AD55E5988E9D",
      "name": "Tag-37"
    }
  ]
}
```
Here is an example of a customer item:

```json
{
  "id": "022BB1FA-35E6-4CC5-9079-8EA61FE7FAAE",
  "type": "customer",
  "customerId": "022BB1FA-35E6-4CC5-9079-8EA61FE7FAAE",
  "title": "Mr.",
  "firstName": "Mark",
  "lastName": "Hanson",
  "emailAddress": "mark3@adventure-works.com",
  "phoneNumber": "497-555-0147",
  "creationDate": "2011-05-31T00:00:00",
  "addresses": [
  ],
  "password": {
      "hash": "HL1biryFMkXxgvm28cDEjA+HuPxSboUAW0Ikh/hqmmU=",
      "salt": "F037BBAB"
  },
  "salesOrderCount": 12
}
```

Here is an example of a sales order item:

```json
{
  "id": "2751BDCE-208C-45B3-9252-64650AC3400A",
  "type": "salesOrder",
  "customerId": "64B7B145-43AD-4B85-B7CD-571F10879336",
  "orderDate": "2014-05-18T00:00:00",
  "shipDate": "2014-05-25T00:00:00",
  "details": [
      {
          "sku": "TI-T723",
          "name": "Touring Tire",
          "price": 28.99,
          "quantity": 1
      },
      {
          "sku": "CL-9009",
          "name": "Bike Wash - Dissolver",
          "price": 7.95,
          "quantity": 1
      },
      {
          "sku": "TT-T092",
          "name": "Touring Tire Tube",
          "price": 4.99,
          "quantity": 1
      }
  ]
}
```
