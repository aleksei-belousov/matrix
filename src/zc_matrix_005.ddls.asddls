@EndUserText.label: 'Matrix'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define root view entity ZC_MATRIX_005 provider contract transactional_query as projection on ZI_MATRIX_005 as Matrix
{
    key MatrixUUID,
    MatrixID,
    @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_SalesOrderType', element: 'SalesOrderType' } } ]
    SalesOrderType,
    @Consumption.valueHelpDefinition: [ { entity: { name: 'I_SalesOrganization', element: 'SalesOrganization' } } ]
    SalesOrganization,
    @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_DistributionChannel', element: 'DistributionChannel' } } ]
    DistributionChannel,
    @Consumption.valueHelpDefinition: [ { entity: { name: 'I_Division', element: 'Division' } } ]
    OrganizationDivision,
    @Consumption.valueHelpDefinition: [ { entity: { name: 'I_Customer', element: 'Customer' } } ]
    SoldToParty,
    @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_MODEL_005', element: 'ModelID' } } ]
    Model,
    @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_COLOR_005', element: 'ColorID' } } ]
    Color,
    @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_MATRIXTYPE_005', element: 'MatrixTypeID' } } ]
    MatrixTypeID,
    @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_COUNTRY_005', element: 'CountryID' } } ]
    Country,
    PurchaseOrderByCustomer,
    CreationDate,
    CreationTime,
    SalesOrderID,
    SalesOrderURL,
    CustomerURL,
    CreatedBy,
    CreatedAt,
    LastChangedBy,
    LastChangedAt,
    LocalLastChangedAt,
    /* Associations */
    _Size: redirected to composition child ZC_SIZE_005,
    _Item: redirected to composition child ZC_ITEM_005
}
