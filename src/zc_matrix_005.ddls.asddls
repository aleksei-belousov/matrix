@EndUserText.label: 'Sales Order'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['SoldToParty', 'SalesOrganization'] // bold style font

define root view entity ZC_MATRIX_005 provider contract transactional_query as projection on ZI_MATRIX_005 as Matrix
{
    key MatrixUUID,
    MatrixID,

    @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_SalesOrderType', element: 'SalesOrderType'}, useForValidation: true } ]
    @EndUserText.label: 'Sales Order Type'
    @ObjectModel.text.element: ['SalesOrderTypeDescription']
    SalesOrderType,
    _SalesOrderType.Description as SalesOrderTypeDescription,

    @Consumption.valueHelpDefinition: [ { entity: { name: 'I_SalesOrganization', element: 'SalesOrganization' } } ]
    SalesOrganization,

    @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_DistributionChannel', element: 'DistributionChannel' } } ]
    DistributionChannel,

    @Consumption.valueHelpDefinition: [ { entity: { name: 'I_Division', element: 'Division' } } ]
    OrganizationDivision,

    @Consumption.valueHelpDefinition: [ { entity: { name: 'I_Customer', element: 'Customer' }, useForValidation: true } ]
    @EndUserText.label: 'Customer'
    @ObjectModel.text.element: ['CustomerName']
    SoldToParty,
    _Customer.CustomerName as CustomerName,
    
    @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_MODEL_005A', element: 'ModelID' } } ]
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
    ModelRef,
    ModelRefURL,
//  @ObjectModel.text.element: [ 'Country' ] // it works but in a strange way
    Boolean,
    Hidden01,
    Hidden02,
    Hidden03,
    Hidden04,
    Hidden05,
    Hidden06,
    Hidden07,
    Hidden08,
    Hidden09,
    Hidden10,
    Hidden11,
    Hidden12,
    Hidden13,
    Hidden14,
    Hidden15,
    Hidden16,
    Hidden17,
    Hidden18,
    Hidden19,
    Hidden20,
    Hidden21,
    Criticality01,
    CreatedBy,
    CreatedAt,
    LastChangedBy,
    LastChangedAt,
    LocalLastChangedAt,
    /* Associations */
    _Size: redirected to composition child ZC_SIZE_005,
    _Item: redirected to composition child ZC_ITEM_005,
    _Sizehead: redirected to composition child ZC_SIZEHEAD_005,
    _SalesOrderType,
    _Customer
}
