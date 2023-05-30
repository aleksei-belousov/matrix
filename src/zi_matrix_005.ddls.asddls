@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Matrix'
define root view entity ZI_MATRIX_005 as select from zmatrix_005 as Matrix
composition [0..*] of ZI_SIZE_005 as _Size
composition [0..*] of ZI_ITEM_005 as _Item
{
    key matrixuuid as MatrixUUID,
    matrixid as MatrixID,
    salesordertype as SalesOrderType,
    salesorganization as SalesOrganization,
    distributionchannel as DistributionChannel,
    organizationdivision as OrganizationDivision,
    soldtoparty as SoldToParty,
    model as Model,
    color as Color,
    purchaseorderbycustomer as PurchaseOrderByCustomer,
    creationdate as CreationDate,
    creationtime as CreationTime,
    salesorderid as SalesOrderID,
    salesorderurl as SalesOrderURL,
    customerurl as CustomerURL,
    matrixtypeid as MatrixTypeID,
    createdby as CreatedBy,
    createdat as CreatedAt,
    lastchangedby as LastChangedBy,
    lastchangedat as LastChangedAt,
    locallastchangedat as LocalLastChangedAt,
    _Size, // Make association public
    _Item  // Make association public
}
