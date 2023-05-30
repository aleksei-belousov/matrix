@EndUserText.label: 'Model'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define root view entity ZC_MODEL_005 provider contract transactional_query as projection on ZI_MODEL_005 as Model
{
    key ModelUUID,
    @UI: {  lineItem:       [ { position: 30, label: 'Model ID', cssDefault.width: '300px' } ],
            identification: [ { position: 30, label: 'Model ID', cssDefault.width: '300px' } ],
            selectionField: [ { position: 30 } ] }
    ModelID,
    CreatedBy,
    CreatedAt,
    LastChangedBy,
    LastChangedAt,
    LocalLastChangedAt
}
