@EndUserText.label: 'ZC_ITEM_005'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define view entity ZC_ITEM_005 as projection on ZI_ITEM_005 as Item
{
    key MatrixUUID,
    key ItemID,
    Model,
    Color,
    Cupsize,
    Backsize,
    Product,
    Quantity,
    MatrixTypeID,
    Country,
    Createdby,
    Createdat,
    LastChangedBy,
    LastChangedAt,
    LocalLastChangedAt,
    /* Associations */
    _Matrix : redirected to parent ZC_MATRIX_005
}
