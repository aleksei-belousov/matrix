@EndUserText.label: 'Backsize'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define view entity ZC_BACKSIZE_005 as projection on ZI_BACKSIZE_005 as Backsize
{
    key BacksizeUUID,
    MatrixtypeUUID,
    BackSizeID,
    Description,
    CreatedBy,
    CreatedAt,
    LastChangedBy,
    LastChangedAt,
    LocalLastChangedAt,
    /* Associations */
    _MatrixType : redirected to parent ZC_MATRIXTYPE_005
}
