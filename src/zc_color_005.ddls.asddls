@EndUserText.label: 'Color'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define root view entity ZC_COLOR_005  provider contract transactional_query as projection on ZI_COLOR_005 as Color
{
    key ColorUUID,
    ColorID,
    CreatedBy,
    CreatedAt,
    LastChangedBy,
    LastChangedAt,
    LocalLastChangedAt
}
