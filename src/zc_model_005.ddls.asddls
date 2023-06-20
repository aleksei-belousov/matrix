@EndUserText.label: 'Model'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define root view entity ZC_MODEL_005 provider contract transactional_query as projection on ZI_MODEL_005 as Model
{
    key ModelUUID,
    ModelID,
    Description,
    CreatedBy,
    CreatedAt,
    LastChangedBy,
    LastChangedAt,
    LocalLastChangedAt
}
