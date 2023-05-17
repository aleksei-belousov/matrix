@EndUserText.label: 'ZC_MATRIX_005'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define root view entity ZC_MATRIX_005 provider contract transactional_query as projection on ZI_MATRIX_005 as Matrix
{
    key MatrixUUID,
    MatrixID,
    SalesOrderType,
    SalesOrganization,
    DistributionChannel,
    OrganizationDivision,
    @Consumption.valueHelpDefinition: [ { entity: { name: 'I_Customer', element: 'Customer' } } ]
    SoldToParty,
    Model,
    Color,
    PurchaseOrderByCustomer,
    CreationDate,
    CreationTime,
    SalesOrderID,
    CreatedBy,
    CreatedAt,
    LastChangedBy,
    LastChangedAt,
    LocalLastChangedAt,
    /* Associations */
    _Size: redirected to composition child ZC_SIZE_005,
    _Item: redirected to composition child ZC_ITEM_005
}
