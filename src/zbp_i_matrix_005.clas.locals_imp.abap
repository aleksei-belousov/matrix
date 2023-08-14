CLASS lhc_matrix DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR matrix RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR matrix RESULT result.

    METHODS resume FOR MODIFY
      IMPORTING keys FOR ACTION matrix~resume.

    METHODS create_sales_order FOR MODIFY
      IMPORTING keys FOR ACTION matrix~create_sales_order.

    METHODS update_sales_order FOR MODIFY
      IMPORTING keys FOR ACTION matrix~update_sales_order.

    METHODS get_sales_order FOR MODIFY
      IMPORTING keys FOR ACTION matrix~get_sales_order.

    METHODS on_create FOR DETERMINE ON MODIFY
      IMPORTING keys FOR matrix~on_create.

    METHODS edit FOR MODIFY
      IMPORTING keys FOR ACTION matrix~edit.

    METHODS activate FOR MODIFY
      IMPORTING keys FOR ACTION matrix~activate.

    METHODS on_model_modify FOR DETERMINE ON MODIFY " on modify model
      IMPORTING keys FOR matrix~on_model_modify.

    METHODS on_scheme_save FOR DETERMINE ON SAVE "on save model, color, matrix type, country
      IMPORTING keys FOR matrix~on_scheme_save.

    METHODS check_atp FOR MODIFY
      IMPORTING keys FOR ACTION matrix~check_atp.

    METHODS on_sales_order_create FOR DETERMINE ON MODIFY
      IMPORTING keys FOR matrix~on_sales_order_create.

*   For ATP check
    METHODS get_stock_availability
      IMPORTING
        value(i_plant)              TYPE string
        value(i_product)            TYPE string
        value(i_quantity)           TYPE string
      EXPORTING
        value(o_available_stock)    TYPE string
        value(o_stock)              TYPE string
        value(o_availability)       TYPE string
        value(o_criticality)        TYPE string.

ENDCLASS. " lhc_matrix DEFINITION

CLASS lhc_matrix IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_instance_features.
  ENDMETHOD.

  METHOD Resume.
  ENDMETHOD.

  METHOD create_sales_order.

    DATA it_salesorder TYPE TABLE FOR CREATE i_salesordertp. " Sales Order
    DATA it_salesorder_item TYPE TABLE FOR CREATE i_salesordertp\_Item.  " Item
    DATA wa_salesorder_item LIKE LINE OF it_salesorder_item.
    DATA it_matrix TYPE TABLE FOR UPDATE zi_matrix_005. " Matrix
    DATA cid TYPE string.

    LOOP AT keys INTO DATA(key).

        IF ( key-%is_draft = '00' ). " Saved

            SELECT SINGLE * FROM zc_matrix_005 WHERE ( MatrixUUID = @key-MatrixUUID ) INTO @DATA(wa_matrix_005).

            IF ( wa_matrix_005-SalesOrderID IS NOT INITIAL ).
                APPEND VALUE #( %key = key-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Sales Order already exists.' ) ) TO reported-matrix.
                RETURN.
            ENDIF.

*           Conversion of sales document type from external to internal format (conversion exits are not permitted, therefore - we have to use hard code)
            CASE wa_matrix_005-SalesOrderType.
                WHEN 'OR'. wa_matrix_005-SalesOrderType = 'TA'.
            ENDCASE.

*           Make Sales Order (Header)
            it_salesorder = VALUE #(
                (
                    %cid = 'root'
                    %data = VALUE #(
                        salesordertype          = |{ wa_matrix_005-SalesOrderType ALPHA = IN }|         " 'TA'
                        salesorganization       = |{ wa_matrix_005-SalesOrganization ALPHA = IN }|      " '1010'
                        distributionchannel     = |{ wa_matrix_005-DistributionChannel ALPHA = IN }|    " '10'
                        organizationdivision    = |{ wa_matrix_005-OrganizationDivision ALPHA = IN }|   " '00'
                        soldtoparty             = |{ wa_matrix_005-SoldToParty ALPHA = IN }|            " '0010100014'
                    )
                )
            ).

*           Read Matrix Items
            READ ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Matrix BY \_Item
                ALL FIELDS WITH CORRESPONDING #( keys )
                RESULT DATA(it_matrix_item)
                FAILED failed
                REPORTED reported.

*           SORT
            SORT it_matrix_item STABLE BY ItemID.

*           Make Sales Order Items
            LOOP AT it_matrix_item INTO DATA(wa_matrix_item).
                cid = CONV string( sy-tabix ).
                APPEND VALUE #(
                    %cid_ref = 'root'
                    SalesOrder = space
                    %target = VALUE #( (
                        %cid                = cid
                        Product             = wa_matrix_item-Product
                        RequestedQuantity   = wa_matrix_item-Quantity
                    ) )
                ) TO it_salesorder_item.
            ENDLOOP.

*           Create Sales Order
            MODIFY ENTITIES OF i_salesordertp
                ENTITY salesorder
                CREATE FIELDS (
                    salesordertype
                    salesorganization
                    distributionchannel
                    organizationdivision
                    soldtoparty
                )
                WITH it_salesorder
                CREATE BY \_item
                FIELDS (
                    Product
                    RequestedQuantity
                )
                WITH it_salesorder_item
                MAPPED DATA(ls_mapped)
                FAILED DATA(ls_failed)
                REPORTED DATA(ls_reported).

            "retrieve the created sale order
            zbp_i_matrix_005=>mapped_sales_order-salesorder = ls_mapped-salesorder.

*           Read Sales Order
            READ ENTITIES OF i_salesordertp
                ENTITY salesorder
                FROM VALUE #( ( salesorder = space ) )
                RESULT DATA(lt_so_head)
                REPORTED DATA(ls_reported_read).

*           Update Matrix (root)
            READ TABLE lt_so_head INTO DATA(ls_so_head) INDEX 1.
            IF ( sy-subrc = 0 ).
                it_matrix = VALUE #( (
                    %tky                    = key-%tky
                    CreationDate            = ls_so_head-CreationDate
                    CreationTime            = ls_so_head-CreationTime
                 ) ).
                MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                    ENTITY Matrix
                    UPDATE FIELDS ( CreationDate CreationTime )
                    WITH it_matrix
                    FAILED failed
                    MAPPED mapped
                    REPORTED reported.
            ELSE.
                APPEND VALUE #( %key = key-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Sales Order not created.' ) ) TO reported-matrix.
                LOOP AT ls_reported-salesorder INTO DATA(wa_salesorder).
                    "APPEND VALUE #( %key = key-%key %msg = new_message_with_text( severity = wa_salesorder-%msg->m_severity text = wa_salesorder-%msg->if_message~get_text( ) ) ) TO reported-matrix.
                    DATA(severity)  = wa_salesorder-%msg->m_severity.
                    DATA(msgno)     = wa_salesorder-%msg->if_t100_message~t100key-msgno.
                    DATA(msgid)     = wa_salesorder-%msg->if_t100_message~t100key-msgid.
                    DATA(msgty)     = wa_salesorder-%msg->if_t100_dyn_msg~msgty.
                    DATA(msgv1)     = wa_salesorder-%msg->if_t100_dyn_msg~msgv1.
                    DATA(msgv2)     = wa_salesorder-%msg->if_t100_dyn_msg~msgv2.
                    DATA(msgv3)     = wa_salesorder-%msg->if_t100_dyn_msg~msgv3.
                    DATA(msgv4)     = wa_salesorder-%msg->if_t100_dyn_msg~msgv4.
                    APPEND VALUE #( %key = key-%key %msg = new_message( severity = severity id = msgid number = msgno v1 = msgv1 v2 = msgv2 v3 = msgv3 v4 = msgv4 ) ) TO reported-matrix.
                ENDLOOP.
            ENDIF.

        ENDIF.

        IF ( key-%is_draft = '01' ). " Draft
            APPEND VALUE #( %key = key-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Data not saved.' ) ) TO reported-matrix.
        ENDIF.

    ENDLOOP.

  ENDMETHOD. " create_sales_order

  METHOD update_sales_order.

    LOOP AT keys INTO DATA(key).

        IF ( key-%is_draft = '00' ). " Saved

            SELECT SINGLE * FROM zc_matrix_005 WHERE ( MatrixUUID = @key-MatrixUUID ) INTO @DATA(wa_matrix_005).

            IF ( wa_matrix_005-SalesOrderID IS INITIAL ).
                APPEND VALUE #( %key = key-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Sales Order not yet created.' ) ) TO reported-matrix.
                RETURN.
            ENDIF.

*           Update Sales Order (Header)
            MODIFY ENTITIES OF I_SalesOrderTP
                ENTITY SalesOrder
                UPDATE FIELDS (
*                    SalesOrganization
*                    DistributionChannel
*                    OrganizationDivision
                    SoldToParty
                    PurchaseOrderByCustomer
                )
                WITH VALUE #( (
                    %key-SalesOrder         = wa_matrix_005-SalesOrderID                    " '0000000140'
*                    SalesOrganization       = wa_matrix_005-SalesOrganization               " '1010'
*                    DistributionChannel     = wa_matrix_005-DistributionChannel             " '10'
*                    OrganizationDivision    = wa_matrix_005-OrganizationDivision            " '00'
                    SoldToParty             = |{ wa_matrix_005-SoldToParty ALPHA = IN }|    " '0010100014'
                    PurchaseOrderByCustomer = wa_matrix_005-PurchaseOrderByCustomer         " '12350'
                ) )
                MAPPED DATA(ls_order_mapped)
                FAILED DATA(ls_order_failed)
                REPORTED DATA(ls_order_reported).

*           Read Matrix Items
            READ ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Matrix BY \_Item
                ALL FIELDS WITH CORRESPONDING #( keys )
                RESULT DATA(it_matrix_item)
                FAILED DATA(ls_matrix_item_failed)
                REPORTED DATA(ls_matrix_item_reported).

*           SORT
            SORT it_matrix_item STABLE BY Product.

*           Read Sales Order Items
            READ ENTITIES OF i_salesordertp
                ENTITY SalesOrder BY \_Item
                FROM VALUE #( ( salesorder = wa_matrix_005-SalesOrderID ) )
                RESULT DATA(it_order_item)
                FAILED DATA(ls_item_failed)
                REPORTED DATA(ls_item_reported).

*           SORT
            SORT it_order_item STABLE BY Product.

*           Update Sales Order Items (have been changed in matrix)
            LOOP AT it_matrix_item INTO DATA(wa_matrix_item).
                READ TABLE it_order_item WITH KEY Product = wa_matrix_item-Product BINARY SEARCH INTO DATA(wa_order_item).
                IF ( sy-subrc = 0 ).
                    MODIFY ENTITIES OF i_salesordertp
                        ENTITY SalesOrderItem
                        UPDATE FIELDS (
*                            Product
                            RequestedQuantity
                        )
                        WITH VALUE #( (
                            %key-SalesOrder     = wa_order_item-SalesOrder      " '0000000140'          " C(10)
                            %key-SalesOrderItem = wa_order_item-SalesOrderItem  " '000010'              " N(6)
*                            Product             = wa_matrix_item-Product       " 'TG000231-048-A-060'  " C(20)
                            RequestedQuantity   = wa_matrix_item-Quantity       " '5'
                        ) )
                        MAPPED DATA(ls_mapped1)
                        FAILED DATA(ls_failed1)
                        REPORTED DATA(ls_reported1).
                ENDIF.

            ENDLOOP.

*           Delete Sales Order Items (have been deleted from matrix)
            LOOP AT it_order_item INTO wa_order_item.
                READ TABLE it_matrix_item WITH KEY Product = wa_order_item-Product BINARY SEARCH TRANSPORTING NO FIELDS.
                IF ( sy-subrc <> 0 ).
                    MODIFY ENTITIES OF i_salesordertp
                      ENTITY SalesOrderItem
                        DELETE FROM VALUE #( (
                            %key-salesorder     = wa_order_item-SalesOrder      " '0000000140'
                            %key-salesorderitem = wa_order_item-SalesOrderItem  " '000010'
                        ) )
                      MAPPED   DATA(ls_mapped2)
                      FAILED   DATA(ls_failed2)
                      REPORTED DATA(ls_reported2).
                ENDIF.
            ENDLOOP.

*           Create Sales Order Items (have been added to matrix)
            LOOP AT it_matrix_item INTO wa_matrix_item.
                READ TABLE it_order_item WITH KEY Product = wa_matrix_item-Product BINARY SEARCH TRANSPORTING NO FIELDS.
                IF ( sy-subrc <> 0 ).
*                   Create Sales Order Item
                    MODIFY ENTITIES OF i_salesordertp
                        ENTITY SalesOrder
                        CREATE BY \_item AUTO FILL CID
                        FIELDS (
                            Product
                            RequestedQuantity
                        )
                        WITH VALUE #( (
                            SalesOrder = wa_matrix_005-SalesOrderID
                            %target = VALUE #( (
                                Product             = wa_matrix_item-Product
                                RequestedQuantity   = wa_matrix_item-Quantity
                            ) )
                        ) )
                        MAPPED DATA(ls_mapped3)
                        FAILED DATA(ls_failed3)
                        REPORTED DATA(ls_reported3).
                ENDIF.
            ENDLOOP.

        ENDIF.

        IF ( key-%is_draft = '01' ). " Draft
            APPEND VALUE #( %key = key-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Data not saved.' ) ) TO reported-matrix.
        ENDIF.

    ENDLOOP.

  ENDMETHOD. " update_sales_order

  METHOD get_sales_order.

    DATA it_matrix_update   TYPE TABLE FOR UPDATE zi_matrix_005\\Matrix.    " Matrix
    DATA it_item_create     TYPE TABLE FOR CREATE zi_matrix_005\_Item.      " Item
    DATA it_size_update     TYPE TABLE FOR UPDATE zi_matrix_005\\Size .     " Size
    DATA wa_size_update     LIKE LINE OF it_size_update.

    DATA product      TYPE string VALUE ''.
    DATA quantity     TYPE string VALUE ''.
    DATA model        TYPE string VALUE ''.
    DATA color        TYPE string VALUE ''.
    DATA backsize     TYPE string VALUE ''.
    DATA cupsize      TYPE string VALUE ''.
    DATA productURL   TYPE string VALUE ''.

    DATA tabix TYPE sy-tabix.

   " Read transfered instances
    READ ENTITIES OF zi_matrix_005  IN LOCAL MODE
        ENTITY Matrix
        ALL FIELDS
        WITH CORRESPONDING #( keys )
        RESULT DATA(entities).

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<entity>).

        IF ( <entity>-%is_draft = '00' ). " Saved

*            SELECT SINGLE
*                    *
*                FROM
*                    i_salesordertp
*                WHERE
*                    ( CreationDate = @<entity>-CreationDate ) AND
*                    ( CreationTime = @<entity>-CreationTime )
*                INTO
*                    @DATA(wa_salesordertp).
*
*            IF ( sy-subrc <> 0 ).
*
*                APPEND VALUE #( %key = <entity>-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Sales Order not created yet.' ) ) TO reported-matrix.
*                RETURN.
*
*            ELSE.
*
*                DATA(salesOrderURL) = |/ui#SalesOrder-manageV2&/SalesOrderManage('| && condense( val = |{ wa_salesordertp-SalesOrder ALPHA = OUT }| ) && |')|.
*                "DATA(salesOrderURL) = '/ui#SalesDocument-display?sap-ui-tech-hint=GUI&SalesDocument=' && wa_salesordertp-SalesOrder. " old version on VA03
*
**               Sales Order ID
*                it_matrix_update = VALUE #( (
*                    %tky            = <entity>-%tky
*                    SalesOrderID    = wa_salesordertp-SalesOrder
*                    SalesOrderURL   = salesOrderURL
*                ) ).
*
**               Update Matrix (Sales Order ID)
*                MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
*                    ENTITY Matrix
*                    UPDATE FIELDS ( SalesOrderID SalesOrderURL )
*                    WITH it_matrix_update
*                    FAILED DATA(it_failed)
*                    MAPPED DATA(it_mapped)
*                    REPORTED DATA(it_reported).

*               Restore Items from Sales Order :

            IF ( <entity>-SalesOrderID IS INITIAL ).
                APPEND VALUE #( %key = <entity>-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Sales Order not created yet.' ) ) TO reported-matrix.
                RETURN.
            ELSE.

*               Read Actual Matrix Items
                READ ENTITIES OF zi_matrix_005 IN LOCAL MODE
                    ENTITY Matrix
                    BY \_Item
                    ALL FIELDS WITH VALUE #( ( MatrixUUID = <entity>-MatrixUUID ) )
                    RESULT DATA(lt_matrix_item)
                    FAILED DATA(ls_read_failed)
                    REPORTED DATA(ls_read_reported).

                SORT lt_matrix_item STABLE BY ItemID.

*               Delete Actual Matrix Items
                LOOP AT lt_matrix_item INTO DATA(ls_matrix_item).
                    MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                        ENTITY Item
                        DELETE FROM VALUE #( ( MatrixUUID = <entity>-MatrixUUID ItemID = ls_matrix_item-ItemID ) )
                        FAILED DATA(ls_delete_failed)
                        MAPPED DATA(ls_delete_mapped)
                        REPORTED DATA(ls_delete_reported).
                ENDLOOP.

*               Read Sales Order Items
                READ ENTITIES OF i_salesordertp
                    ENTITY SalesOrder
                    BY \_Item
                    ALL FIELDS WITH VALUE #( ( salesorder = <entity>-SalesOrderID ) )
                    RESULT DATA(lt_salesorder_item)
                    FAILED DATA(ls_failed_read)
                    REPORTED DATA(ls_reported_read).

                SORT lt_salesorder_item STABLE BY SalesOrderItem.

*               Create New Matrix Items
                LOOP AT lt_salesorder_item INTO DATA(ls_salesorder_item).

                    product   = ls_salesorder_item-product.
                    SPLIT product AT '-' INTO model color cupsize backsize.
                    quantity = round( val  = ls_salesorder_item-RequestedQuantity dec  = 0 ).
                    CONDENSE quantity NO-GAPS.
                    productURL  = '/ui#Material-displayFactSheet&/C_ProductObjPg(''' && product && ''')'. " '0205286-705-H-075'

                    APPEND VALUE #(
                        MatrixUUID = <entity>-MatrixUUID
                        %target = VALUE #( (
                            %cid       = sy-tabix
                            ItemID     = sy-tabix
                            Model      = model
                            Color      = color
                            Cupsize    = cupsize
                            Backsize   = backsize
                            Product    = product
                            Quantity   = quantity
                            ProductURL = productURL
                        ) )
                    ) TO it_item_create.

                ENDLOOP.

                MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                    ENTITY Matrix
                    CREATE BY \_Item
                    FIELDS ( ItemID Model Color Cupsize Backsize Product Quantity ProductURL )
                    WITH it_item_create
                    FAILED DATA(ls_item_failed)
                    MAPPED DATA(ls_item_mapped)
                    REPORTED DATA(ls_item_reported).
            ENDIF.

*           Update Size table from Item table:

*           Read Size Head table
            READ ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Matrix
                BY \_Sizehead
                ALL FIELDS WITH VALUE #( ( MatrixUUID = <entity>-MatrixUUID ) )
                RESULT DATA(lt_sizehead)
                FAILED DATA(ls_failed_sizehead_read)
                REPORTED DATA(ls_reported_sizehead_read).

            READ TABLE lt_sizehead INTO DATA(ls_sizehead1) WITH KEY SizeID = 1.
            READ TABLE lt_sizehead INTO DATA(ls_sizehead2) WITH KEY SizeID = 2.

            READ ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Matrix
                BY \_Size
                ALL FIELDS WITH VALUE #( ( MatrixUUID = <entity>-MatrixUUID ) )
                RESULT DATA(lt_size)
                FAILED DATA(ls_failed_size_read)
                REPORTED DATA(ls_reported_size_read).

*           Copy Size table to Size Update table
            LOOP AT lt_size INTO DATA(wa_size).
                MOVE-CORRESPONDING wa_size TO wa_size_update.
                CLEAR wa_size_update-a.
                CLEAR wa_size_update-b.
                CLEAR wa_size_update-c.
                CLEAR wa_size_update-d.
                CLEAR wa_size_update-e.
                CLEAR wa_size_update-f.
                CLEAR wa_size_update-g.
                CLEAR wa_size_update-h.
                CLEAR wa_size_update-i.
                CLEAR wa_size_update-j.
                CLEAR wa_size_update-k.
                CLEAR wa_size_update-l.
                APPEND wa_size_update TO it_size_update.
            ENDLOOP.

*           Fill Quantities
            LOOP AT it_item_create INTO DATA(wa_item_create).
                LOOP AT wa_item_create-%target INTO DATA(target).
                    product = target-Product.
                    SPLIT product AT '-' INTO model color cupsize backsize.
                    IF ( ( model = <entity>-Model ) AND ( color = <entity>-Color ) ).
                        quantity = target-Quantity.
                        LOOP AT it_size_update INTO wa_size_update.
                            tabix = sy-tabix.
                            IF ( cupsize = wa_size_update-Back ).
                                CASE backsize.
                                    WHEN ls_sizehead2-a.
                                        wa_size_update-a = quantity.
                                    WHEN ls_sizehead2-b.
                                        wa_size_update-b = quantity.
                                    WHEN ls_sizehead2-c.
                                        wa_size_update-c = quantity.
                                    WHEN ls_sizehead2-d.
                                        wa_size_update-d = quantity.
                                    WHEN ls_sizehead2-e.
                                        wa_size_update-e = quantity.
                                    WHEN ls_sizehead2-f.
                                        wa_size_update-f = quantity.
                                    WHEN ls_sizehead2-g.
                                        wa_size_update-g = quantity.
                                    WHEN ls_sizehead2-h.
                                        wa_size_update-h = quantity.
                                    WHEN ls_sizehead2-i.
                                        wa_size_update-i = quantity.
                                    WHEN ls_sizehead2-j.
                                        wa_size_update-j = quantity.
                                    WHEN ls_sizehead2-k.
                                        wa_size_update-k = quantity.
                                    WHEN ls_sizehead2-l.
                                        wa_size_update-l = quantity.
                                ENDCASE.
                            ENDIF.
                            MODIFY it_size_update FROM wa_size_update INDEX tabix.
                        ENDLOOP.
                    ENDIF.
                ENDLOOP.
            ENDLOOP.

*           Update Actual Size Table
            MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Size
                UPDATE FIELDS ( a b c d e f g h i j k l )
                WITH it_size_update
                MAPPED DATA(ls_size_update_mapped)
                FAILED DATA(ls_size_update_failed)
                REPORTED DATA(ls_size_update_reported).

        ENDIF.

        IF ( <entity>-%is_draft = '01' ). " Draft
            APPEND VALUE #( %key = <entity>-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Data not saved.' ) ) TO reported-matrix.
        ENDIF.

    ENDLOOP.

  ENDMETHOD. " get_sales_order

  METHOD on_create. " on initial create

*    DATA it_matrix_update   TYPE TABLE FOR UPDATE zi_matrix_005\\Matrix.    " Matrix
*    DATA it_sizehead_create TYPE TABLE FOR CREATE zi_matrix_005\_Sizehead.  " Size Head
*    DATA it_size_create     TYPE TABLE FOR CREATE zi_matrix_005\_Size.      " Size

   " Read transfered instances
    READ ENTITIES OF zi_matrix_005  IN LOCAL MODE
        ENTITY Matrix
        ALL FIELDS
        WITH CORRESPONDING #( keys )
        RESULT DATA(entities).

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<entity>).

        IF ( <entity>-%is_draft = '00' ). " Saved (on pressing down Create)

*           Do nothing

        ENDIF.

        IF ( <entity>-%is_draft = '01' ). " Draft (on pressing up Create)

*           Generate New Matrix ID
            DATA matrixid TYPE zi_matrix_005-MatrixID VALUE '0000000000'.
            SELECT MAX( matrixid ) FROM zi_matrix_005 INTO (@matrixid).
            matrixid  = ( matrixid + 1 ).

            MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Matrix
                UPDATE FIELDS (
                    MatrixID
                    SalesOrderType
                    SalesOrganization
                    DistributionChannel
                    OrganizationDivision
                    SoldToParty
                    Model
                    Color
                    MatrixTypeID
                    Country
                )
                WITH VALUE #( (
                    %tky                    = <entity>-%tky
                    MatrixID                = matrixid
                    SalesOrderType          = 'OR'
                    SalesOrganization       = '1000' " '1010'
                    DistributionChannel     = '10'
                    OrganizationDivision    = '00'
                    SoldToParty             = space " '0010100014'
                    Model                   = space
                    Color                   = space
                    MatrixTypeID            = space
                    Country                 = 'DE'
                ) )
                FAILED DATA(ls_matrix_update_failed1)
                MAPPED DATA(ls_matrix_update_mapped1)
                REPORTED DATA(ls_matrix_update_reported1).

*           Variant Management
            MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Matrix
                UPDATE FIELDS ( Hidden00 Hidden01 Hidden02 Hidden03 Hidden04 Hidden05 Hidden06 Hidden07 Hidden08 Hidden09 Hidden10 Hidden11 Hidden12 Hidden13 Hidden14 Hidden15 Hidden16 Hidden17 Hidden18 Hidden19 Hidden20 Hidden21 )
                WITH VALUE #( (
                    %tky     = <entity>-%tky
                    Hidden00 = abap_false
                    Hidden01 = abap_true
                    Hidden02 = abap_true
                    Hidden03 = abap_true
                    Hidden04 = abap_true
                    Hidden05 = abap_true
                    Hidden06 = abap_true
                    Hidden07 = abap_true
                    Hidden08 = abap_true
                    Hidden09 = abap_true
                    Hidden10 = abap_true
                    Hidden11 = abap_true
                    Hidden12 = abap_true
                    Hidden13 = abap_true
                    Hidden14 = abap_true
                    Hidden15 = abap_true
                    Hidden16 = abap_true
                    Hidden17 = abap_true
                    Hidden18 = abap_true
                    Hidden19 = abap_true
                    Hidden20 = abap_true
                    Hidden21 = abap_true
                ) )
                FAILED DATA(ls_matrix_update_failed2)
                MAPPED DATA(ls_matrix_update_mapped2)
                REPORTED DATA(ls_matrix_update_reported2).

*    *       Create Size Head Table
*            MODIFY ENTITY IN LOCAL MODE zi_matrix_005
*              CREATE BY \_Sizehead AUTO FILL CID
*              FIELDS ( MatrixUUID SizeID Back a BackSizeID )
*              WITH VALUE #( (
*                MatrixUUID = <entity>-MatrixUUID
*                %target = VALUE #( (
*                    MatrixUUID = <entity>-MatrixUUID
*                    Back        = '0'
*                    a           = '001'
*                    BackSizeID  = '0'
*                ) )
*              ) )
*              FAILED DATA(ls_sizehead_create_failed1)
*              MAPPED DATA(ls_sizehead_create_mapped1)
*              REPORTED DATA(ls_sizehead_create_reported1).
*
*            MODIFY ENTITY IN LOCAL MODE zi_matrix_005
*              CREATE BY \_Sizehead AUTO FILL CID
*              FIELDS ( MatrixUUID SizeID Back a BackSizeID )
*              WITH VALUE #( (
*                MatrixUUID = key-MatrixUUID
*                %target = VALUE #( (
*                    MatrixUUID = key-MatrixUUID
*                    SizeID      = 2
*                    Back        = '0'
*                    a           = '001'
*                    BackSizeID  = '0'
*                ) )
*              ) )
*              FAILED DATA(ls_sizehead_create_failed2)
*              MAPPED DATA(ls_sizehead_create_mapped2)
*              REPORTED DATA(ls_sizehead_create_reported2).
*
*    *       Create Size Table
*            MODIFY ENTITY IN LOCAL MODE zi_matrix_005
*              CREATE BY \_Size AUTO FILL CID
*              FIELDS ( MatrixUUID SizeID Back BackSizeID )
*              WITH VALUE #( (
*                %tky = <entity>-%tky
*                MatrixUUID = <entity>-MatrixUUID
*                %target = VALUE #( (
*                    MatrixUUID = <entity>-MatrixUUID
*                    SizeID      = 1
*                    Back        = '0'
*                    BackSizeID  = '0'
*                ) )
*              ) )
*              FAILED DATA(it_size_create_failed)
*              MAPPED DATA(it_size_create_mapped)
*              REPORTED DATA(it_size_create_reported).

*    *       Create Size Table:
*
*    *       Read Matrix
*            READ ENTITIES OF zi_matrix_005 IN LOCAL MODE
*                ENTITY Matrix
*                FROM VALUE #( ( %tky = <entity>-%tky ) )
*                RESULT DATA(it_matrix_result)
*                REPORTED DATA(ls_matrix_read_reported).
*
*            LOOP AT it_matrix_result INTO DATA(wa_matrix_result).
*
*    *           Populate the size table (field Back only)
*                APPEND VALUE #( %is_draft = 01 MatrixUUID = <entity>-MatrixUUID %target = VALUE #( (
*                    MatrixUUID = wa_matrix_result-MatrixUUID SizeID = 1 Back = '0' ) ) ) TO it_size_create.
*
*                " Create Size Table
*                MODIFY ENTITY IN LOCAL MODE zi_matrix_005
*                  CREATE BY \_Size AUTO FILL CID
*                  FIELDS ( MatrixUUID SizeID Back )
*                  WITH it_size_create
*                  FAILED DATA(it_size_create_failed)
*                  MAPPED DATA(it_size_create_mapped)
*                  REPORTED DATA(it_size_create_reported).
*
*            ENDLOOP.
*
*    *       Set Link to Customer
*            LOOP AT it_matrix_result INTO wa_matrix_result.
*                DATA(customerURL) = |/ui#Customer-displayFactSheet?sap-ui-tech-hint=GUI&/C_CustomerOP('| && condense( val = |{ wa_matrix_result-soldtoparty ALPHA = OUT }| ) && |')|.
*                MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
*                    ENTITY Matrix
*                    UPDATE FIELDS ( CustomerURL )
*                    WITH VALUE #( (
*                        %key        = <entity>-%key
*                        CustomerURL = customerURL
*                    ) ).
*            ENDLOOP.

        ENDIF.

    ENDLOOP.

  ENDMETHOD. " on_create

  METHOD Edit. " Edit
    LOOP AT keys INTO DATA(key).
        APPEND VALUE #( %key = key-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success text = 'Edit.'  ) ) TO reported-matrix.
    ENDLOOP.
  ENDMETHOD. " Edit

  METHOD Activate. " pressing Save button

    DATA it_item_create TYPE TABLE FOR CREATE zi_matrix_005\_Item. " Item
    DATA wa_item_create LIKE LINE OF it_item_create.
    DATA it_item_update TYPE TABLE FOR UPDATE zi_matrix_005\\Item. " Item
    DATA wa_item_update LIKE LINE OF it_item_update.

    DATA cid TYPE string.

    DATA plant              TYPE string VALUE '1000'.
    DATA model              TYPE string.
    DATA color              TYPE string.
    DATA cupsize            TYPE string.
    DATA backsize           TYPE string.
    DATA product            TYPE string.
    DATA quantity           TYPE string.
    DATA stock              TYPE string.
    DATA available_stock    TYPE string.
    DATA availability       TYPE string.
    DATA criticality        TYPE string.
    DATA productURL         TYPE string.

    LOOP AT keys INTO DATA(key).

        APPEND VALUE #( %key = key-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success text = 'Activate.' ) ) TO reported-matrix.

*       Read Actual Matrix
        SELECT SINGLE * FROM zmatrix_005  WHERE ( matrixuuid = @key-MatrixUUID ) INTO @DATA(wa_matrix).

*       Read Matrix Draft
        SELECT SINGLE * FROM zmatrix_005d WHERE ( matrixuuid = @key-MatrixUUID ) INTO @DATA(wa_matrix_draft).

        plant = wa_matrix_draft-SalesOrganization.

*       Set Customer URL
        DATA(customerURL)   = |/ui#Customer-displayFactSheet?sap-ui-tech-hint=GUI&/C_CustomerOP('| && condense( val = |{ wa_matrix_draft-soldtoparty ALPHA = OUT }| ) && |')|.

*       Set Model Ref URL
        DATA(modelRef)      = |Link|.
        DATA(modelRefURL)   = |/sap/bc/adt/businessservices/odatav4/feap?feapParams=CuCCxuuHCuCvsxysDDICxCuCxsxysDDICDDDEC77nWsacXY%60sDDI777777ngXsacXY%60sDDI77DDDE77ngVsacXY%60sDDI&sap-ui-language=EN&sap-client=080|.

*       Set Color Ref URL
        DATA(colorRef)      = |Link|.
        DATA(colorRefURL)   = |/sap/bc/adt/businessservices/odatav4/feap?feapParams=CuCCxuuHCuCvswsDDICxCuCxswsDDICDDDEC77nWsWc%60cfsDDI777777ngXsWc%60cfsDDI77DDDE77ngVsWc%60cfsDDI&sap-ui-language=EN&sap-client=080|.

*       Set Country Ref URL
        DATA(countryRef)    = |Link|.
        DATA(countryRefURL) = |/sap/bc/adt/businessservices/odatav4/feap?feapParams=CuCCxuuHCuCvswsDDICxCuCxswsDDICDDDEC77nWsWcibhfmsDDI777777ngXsWcibhfmsDDI77DDDE77ngVsWcibhfmsDDI&sap-ui-language=EN&sap-client=080|.

*       Set Sold To Party
        DATA(soldToParty)   = |{ wa_matrix_draft-SoldToParty ALPHA = IN }|. " '0010100014'

        MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
            ENTITY Matrix
            UPDATE FIELDS ( CustomerURL ModelRef ModelRefURL ColorRef ColorRefURL CountryRef CountryRefURL SoldToParty )
            WITH VALUE #( (
                %key          = key-%key
                CustomerURL   = customerURL
                ModelRef      = modelRef
                ModelRefURL   = modelRefURL
                ColorRef      = colorRef
                ColorRefURL   = colorRefURL
                CountryRef    = countryRef
                CountryRefURL = countryRefURL
                SoldToParty   = soldToParty
            ) ).


*       If model/color changed - do not generate items
        IF ( ( wa_matrix-model <> wa_matrix_draft-model ) OR ( wa_matrix-color <> wa_matrix_draft-color ) ).
            RETURN.
        ENDIF.

*       Read Size Table (Draft)
        SELECT * FROM zsize_005d WHERE ( MatrixUUID = @key-MatrixUUID ) ORDER By back INTO TABLE @DATA(it_size).

*       Find max item id (from Draft)
        SELECT MAX( ItemID ) FROM zitem_005d WHERE ( ( MatrixUUID = @key-MatrixUUID ) AND ( draftentityoperationcode <> 'D' ) ) INTO @DATA(maxid).

        model       = wa_matrix-Model.
        color       = wa_matrix-Color.

*       Delete Items with the same Model and Color

*       Read Actual Item Table
        READ ENTITIES OF zi_matrix_005 IN LOCAL MODE
            ENTITY Matrix
            BY \_Item
            ALL FIELDS WITH VALUE #( ( MatrixUUID = key-MatrixUUID ) )
            RESULT DATA(lt_item)
            FAILED DATA(ls_read_failed)
            REPORTED DATA(ls_read_reported).

        SORT lt_item STABLE BY ItemID.

*       Delete (Old) Items with the same Model and Color
        LOOP AT lt_item INTO DATA(ls_item) WHERE ( ( Model = model ) AND ( Color = color ) ).
            MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Item
                DELETE FROM VALUE #( ( MatrixUUID = key-MatrixUUID ItemID = ls_item-ItemID ) )
                FAILED DATA(ls_delete_failed)
                MAPPED DATA(ls_delete_mapped)
                REPORTED DATA(ls_delete_reported).
        ENDLOOP.

*       Read Actual Size Head Table
        READ ENTITIES OF zi_matrix_005 IN LOCAL MODE
            ENTITY Matrix
            BY \_Sizehead
            ALL FIELDS WITH VALUE #( ( MatrixUUID = key-MatrixUUID ) )
            RESULT DATA(lt_sizehead)
            FAILED DATA(ls_read_sizehead_failed)
            REPORTED DATA(ls_read_sizehead_reported).

        SORT lt_sizehead STABLE BY SizeID.

        READ TABLE lt_sizehead INTO DATA(ls_sizehead1) WITH KEY SizeID = 1.
        READ TABLE lt_sizehead INTO DATA(ls_sizehead2) WITH KEY SizeID = 2.

*       Add New Items based on Actual Size table
        LOOP AT it_size INTO DATA(wa_size).
            IF ( wa_size-a IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = ls_sizehead2-a.
                cupsize     = wa_size-backsizeid.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
                quantity    = wa_size-a.
                get_stock_availability( EXPORTING i_plant           = plant
                                                  i_product         = product
                                                  i_quantity        = quantity
                                        IMPORTING o_stock           = stock
                                                  o_available_stock = available_stock
                                                  o_availability    = availability
                                                  o_criticality     = criticality ).
                productURL  = '/ui#Material-displayFactSheet&/C_ProductObjPg(''' && product && ''')'. " '0205286-705-H-075'
                wa_item_create = VALUE #(
                    MatrixUUID = key-MatrixUUID
                    %target = VALUE #( (
                        %cid            = cid
                        ItemID          = cid
                        MatrixUUID      = wa_matrix-MatrixUUID
                        Cupsize         = cupsize
                        Backsize        = backsize
                        Quantity        = quantity
                        Model           = model
                        Color           = color
                        Product         = product
                        Stock           = stock
                        AvailableStock  = available_stock
                        Availability    = availability
                        Criticality01   = criticality
                        ProductURL      = productURL
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-b IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = ls_sizehead2-b.
                cupsize     = wa_size-backsizeid.
                quantity    = wa_size-b.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
                get_stock_availability( EXPORTING i_plant           = plant
                                                  i_product         = product
                                                  i_quantity        = quantity
                                        IMPORTING o_stock           = stock
                                                  o_available_stock = available_stock
                                                  o_availability    = availability
                                                  o_criticality     = criticality ).
                productURL  = '/ui#Material-displayFactSheet&/C_ProductObjPg(''' && product && ''')'. " '0205286-705-H-075'
                wa_item_create = VALUE #(
                    MatrixUUID = key-MatrixUUID
                    %target = VALUE #( (
                        %cid            = cid
                        ItemID          = cid
                        MatrixUUID      = wa_matrix-MatrixUUID
                        Cupsize         = cupsize
                        Backsize        = backsize
                        Quantity        = quantity
                        Model           = model
                        Color           = color
                        Product         = product
                        Stock           = stock
                        AvailableStock  = available_stock
                        Availability    = availability
                        Criticality01   = criticality
                        ProductURL      = productURL
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-c IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = ls_sizehead2-c.
                cupsize     = wa_size-backsizeid.
                quantity    = wa_size-c.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
                get_stock_availability( EXPORTING i_plant           = plant
                                                  i_product         = product
                                                  i_quantity        = quantity
                                        IMPORTING o_stock           = stock
                                                  o_available_stock = available_stock
                                                  o_availability    = availability
                                                  o_criticality     = criticality ).
                productURL  = '/ui#Material-displayFactSheet&/C_ProductObjPg(''' && product && ''')'. " '0205286-705-H-075'
                wa_item_create = VALUE #(
                    MatrixUUID = key-MatrixUUID
                    %target = VALUE #( (
                        %cid            = cid
                        ItemID          = cid
                        MatrixUUID      = wa_matrix-MatrixUUID
                        Cupsize         = cupsize
                        Backsize        = backsize
                        Quantity        = quantity
                        Model           = model
                        Color           = color
                        Product         = product
                        Stock           = stock
                        AvailableStock  = available_stock
                        Availability    = availability
                        Criticality01   = criticality
                        ProductURL      = productURL
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-d IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = ls_sizehead2-d.
                cupsize     = wa_size-backsizeid.
                quantity    = wa_size-d.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
                get_stock_availability( EXPORTING i_plant           = plant
                                                  i_product         = product
                                                  i_quantity        = quantity
                                        IMPORTING o_stock           = stock
                                                  o_available_stock = available_stock
                                                  o_availability    = availability
                                                  o_criticality     = criticality ).
                productURL  = '/ui#Material-displayFactSheet&/C_ProductObjPg(''' && product && ''')'. " '0205286-705-H-075'
                wa_item_create = VALUE #(
                    MatrixUUID = key-MatrixUUID
                    %target = VALUE #( (
                        %cid            = cid
                        ItemID          = cid
                        MatrixUUID      = wa_matrix-MatrixUUID
                        Cupsize         = cupsize
                        Backsize        = backsize
                        Quantity        = quantity
                        Model           = model
                        Color           = color
                        Product         = product
                        Stock           = stock
                        AvailableStock  = available_stock
                        Availability    = availability
                        Criticality01   = criticality
                        ProductURL      = productURL
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-e IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = ls_sizehead2-e.
                cupsize     = wa_size-backsizeid.
                quantity    = wa_size-e.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
                get_stock_availability( EXPORTING i_plant           = plant
                                                  i_product         = product
                                                  i_quantity        = quantity
                                        IMPORTING o_stock           = stock
                                                  o_available_stock = available_stock
                                                  o_availability    = availability
                                                  o_criticality     = criticality ).
                productURL  = '/ui#Material-displayFactSheet&/C_ProductObjPg(''' && product && ''')'. " '0205286-705-H-075'
                wa_item_create = VALUE #(
                    MatrixUUID = key-MatrixUUID
                    %target = VALUE #( (
                        %cid            = cid
                        ItemID          = cid
                        MatrixUUID      = wa_matrix-MatrixUUID
                        Cupsize         = cupsize
                        Backsize        = backsize
                        Quantity        = quantity
                        Model           = model
                        Color           = color
                        Product         = product
                        Stock           = stock
                        AvailableStock  = available_stock
                        Availability    = availability
                        Criticality01   = criticality
                        ProductURL      = productURL
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-f IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = ls_sizehead2-f.
                cupsize     = wa_size-backsizeid.
                quantity    = wa_size-f.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
                get_stock_availability( EXPORTING i_plant           = plant
                                                  i_product         = product
                                                  i_quantity        = quantity
                                        IMPORTING o_stock           = stock
                                                  o_available_stock = available_stock
                                                  o_availability    = availability
                                                  o_criticality     = criticality ).
                productURL  = '/ui#Material-displayFactSheet&/C_ProductObjPg(''' && product && ''')'. " '0205286-705-H-075'
                wa_item_create = VALUE #(
                    MatrixUUID = key-MatrixUUID
                    %target = VALUE #( (
                        %cid            = cid
                        ItemID          = cid
                        MatrixUUID      = wa_matrix-MatrixUUID
                        Cupsize         = cupsize
                        Backsize        = backsize
                        Quantity        = quantity
                        Model           = model
                        Color           = color
                        Product         = product
                        Stock           = stock
                        AvailableStock  = available_stock
                        Availability    = availability
                        Criticality01   = criticality
                        ProductURL      = productURL
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-g IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = ls_sizehead2-g.
                cupsize     = wa_size-backsizeid.
                quantity    = wa_size-g.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
                get_stock_availability( EXPORTING i_plant           = plant
                                                  i_product         = product
                                                  i_quantity        = quantity
                                        IMPORTING o_stock           = stock
                                                  o_available_stock = available_stock
                                                  o_availability    = availability
                                                  o_criticality     = criticality ).
                productURL  = '/ui#Material-displayFactSheet&/C_ProductObjPg(''' && product && ''')'. " '0205286-705-H-075'
                wa_item_create = VALUE #(
                    MatrixUUID = key-MatrixUUID
                    %target = VALUE #( (
                        %cid            = cid
                        ItemID          = cid
                        MatrixUUID      = wa_matrix-MatrixUUID
                        Cupsize         = cupsize
                        Backsize        = backsize
                        Quantity        = quantity
                        Model           = model
                        Color           = color
                        Product         = product
                        Stock           = stock
                        AvailableStock  = available_stock
                        Availability    = availability
                        Criticality01   = criticality
                        ProductURL      = productURL
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-h IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = ls_sizehead2-h.
                cupsize     = wa_size-backsizeid.
                quantity    = wa_size-h.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
                get_stock_availability( EXPORTING i_plant           = plant
                                                  i_product         = product
                                                  i_quantity        = quantity
                                        IMPORTING o_stock           = stock
                                                  o_available_stock = available_stock
                                                  o_availability    = availability
                                                  o_criticality     = criticality ).
                productURL  = '/ui#Material-displayFactSheet&/C_ProductObjPg(''' && product && ''')'. " '0205286-705-H-075'
                wa_item_create = VALUE #(
                    MatrixUUID = key-MatrixUUID
                    %target = VALUE #( (
                        %cid            = cid
                        ItemID          = cid
                        MatrixUUID      = wa_matrix-MatrixUUID
                        Cupsize         = cupsize
                        Backsize        = backsize
                        Quantity        = quantity
                        Model           = model
                        Color           = color
                        Product         = product
                        Stock           = stock
                        AvailableStock  = available_stock
                        Availability    = availability
                        Criticality01   = criticality
                        ProductURL      = productURL
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-i IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = ls_sizehead2-i.
                cupsize     = wa_size-backsizeid.
                quantity    = wa_size-i.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
                get_stock_availability( EXPORTING i_plant           = plant
                                                  i_product         = product
                                                  i_quantity        = quantity
                                        IMPORTING o_stock           = stock
                                                  o_available_stock = available_stock
                                                  o_availability    = availability
                                                  o_criticality     = criticality ).
                productURL  = '/ui#Material-displayFactSheet&/C_ProductObjPg(''' && product && ''')'. " '0205286-705-H-075'
                wa_item_create = VALUE #(
                    MatrixUUID = key-MatrixUUID
                    %target = VALUE #( (
                        %cid            = cid
                        ItemID          = cid
                        MatrixUUID      = wa_matrix-MatrixUUID
                        Cupsize         = cupsize
                        Backsize        = backsize
                        Quantity        = quantity
                        Model           = model
                        Color           = color
                        Product         = product
                        Stock           = stock
                        AvailableStock  = available_stock
                        Availability    = availability
                        Criticality01   = criticality
                        ProductURL      = productURL
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-j IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = ls_sizehead2-j.
                cupsize     = wa_size-backsizeid.
                quantity    = wa_size-j.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
                get_stock_availability( EXPORTING i_plant           = plant
                                                  i_product         = product
                                                  i_quantity        = quantity
                                        IMPORTING o_stock           = stock
                                                  o_available_stock = available_stock
                                                  o_availability    = availability
                                                  o_criticality     = criticality ).
                productURL  = '/ui#Material-displayFactSheet&/C_ProductObjPg(''' && product && ''')'. " '0205286-705-H-075'
                wa_item_create = VALUE #(
                    MatrixUUID = key-MatrixUUID
                    %target = VALUE #( (
                        %cid            = cid
                        ItemID          = cid
                        MatrixUUID      = wa_matrix-MatrixUUID
                        Cupsize         = cupsize
                        Backsize        = backsize
                        Quantity        = quantity
                        Model           = model
                        Color           = color
                        Product         = product
                        Stock           = stock
                        AvailableStock  = available_stock
                        Availability    = availability
                        Criticality01   = criticality
                        ProductURL      = productURL
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-k IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = ls_sizehead2-k.
                cupsize     = wa_size-backsizeid.
                quantity    = wa_size-k.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
                get_stock_availability( EXPORTING i_plant           = plant
                                                  i_product         = product
                                                  i_quantity        = quantity
                                        IMPORTING o_stock           = stock
                                                  o_available_stock = available_stock
                                                  o_availability    = availability
                                                  o_criticality     = criticality ).
                productURL  = '/ui#Material-displayFactSheet&/C_ProductObjPg(''' && product && ''')'. " '0205286-705-H-075'
                wa_item_create = VALUE #(
                    MatrixUUID = key-MatrixUUID
                    %target = VALUE #( (
                        %cid            = cid
                        ItemID          = cid
                        MatrixUUID      = wa_matrix-MatrixUUID
                        Cupsize         = cupsize
                        Backsize        = backsize
                        Quantity        = quantity
                        Model           = model
                        Color           = color
                        Product         = product
                        Stock           = stock
                        AvailableStock  = available_stock
                        Availability    = availability
                        Criticality01   = criticality
                        ProductURL      = productURL
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-l IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = ls_sizehead2-l.
                cupsize     = wa_size-backsizeid.
                quantity    = wa_size-l.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
                get_stock_availability( EXPORTING i_plant           = plant
                                                  i_product         = product
                                                  i_quantity        = quantity
                                        IMPORTING o_stock           = stock
                                                  o_available_stock = available_stock
                                                  o_availability    = availability
                                                  o_criticality     = criticality ).
                productURL  = '/ui#Material-displayFactSheet&/C_ProductObjPg(''' && product && ''')'. " '0205286-705-H-075'
                wa_item_create = VALUE #(
                    MatrixUUID = key-MatrixUUID
                    %target = VALUE #( (
                        %cid            = cid
                        ItemID          = cid
                        MatrixUUID      = wa_matrix-MatrixUUID
                        Cupsize         = cupsize
                        Backsize        = backsize
                        Quantity        = quantity
                        Model           = model
                        Color           = color
                        Product         = product
                        Stock           = stock
                        AvailableStock  = available_stock
                        Availability    = availability
                        Criticality01   = criticality
                        ProductURL      = productURL
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.

            " Create New Items
            MODIFY ENTITY IN LOCAL MODE zi_matrix_005
              CREATE BY \_Item AUTO FILL CID
              FIELDS ( ItemID MatrixUUID Model Color Backsize Cupsize Product Quantity Stock AvailableStock Availability Criticality01 ProductURL )
              WITH it_item_create
              FAILED DATA(it_failed)
              MAPPED DATA(it_mapped)
              REPORTED DATA(it_reported).

        ENDLOOP.

*       Renumbering Item Table :

*       Read Item Table
        READ ENTITIES OF zi_matrix_005 IN LOCAL MODE
            ENTITY Matrix
            BY \_Item
            ALL FIELDS WITH VALUE #( ( MatrixUUID = key-MatrixUUID ) )
            RESULT DATA(lt_item2)
            FAILED DATA(ls_read_failed2)
            REPORTED DATA(ls_read_reported2).

*       Delete Item Table
        LOOP AT lt_item2 INTO DATA(ls_item2).
            MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Item
                DELETE FROM VALUE #( ( MatrixUUID = key-MatrixUUID ItemID = ls_item2-ItemID ) )
                FAILED DATA(ls_delete_failed2)
                MAPPED DATA(ls_delete_mapped2)
                REPORTED DATA(ls_delete_reported2).
        ENDLOOP.

*       SORT By Product and Quantity
        SORT lt_item2 STABLE BY Product Quantity.

        CLEAR it_item_create[].
        LOOP AT lt_item2 INTO ls_item2.
            APPEND VALUE #(
                MatrixUUID = key-MatrixUUID
                %target = VALUE #( (
                    %cid            = sy-tabix
                    ItemID          = sy-tabix
                    MatrixUUID      = ls_item2-MatrixUUID
                    Model           = ls_item2-Model
                    Color           = ls_item2-Color
                    Backsize        = ls_item2-Backsize
                    Cupsize         = ls_item2-Cupsize
                    Product         = ls_item2-Product
                    Quantity        = ls_item2-Quantity
                    Stock           = ls_item2-Stock
                    AvailableStock  = ls_item2-AvailableStock
                    Availability    = ls_item2-Availability
                    Criticality01   = ls_item2-Criticality01
                    ProductURL      = ls_item2-ProductURL
                ) )
            ) TO it_item_create.
        ENDLOOP.

        " Create New (renumbered) Items
        MODIFY ENTITY IN LOCAL MODE zi_matrix_005
          CREATE BY \_Item AUTO FILL CID
          FIELDS ( ItemID MatrixUUID Model Color Backsize Cupsize Product Quantity Stock AvailableStock Availability Criticality01 ProductURL )
          WITH it_item_create
          FAILED DATA(ls_create_failed2)
          MAPPED DATA(ls_create_mapped2)
          REPORTED DATA(ls_create_reported2).

    ENDLOOP.

    " Finally, do refresh (Side Effect on _Item)

  ENDMETHOD. " Activate

  METHOD on_model_modify. " on modifying model

   " Read transfered instances
    READ ENTITIES OF zi_matrix_005  IN LOCAL MODE
        ENTITY Matrix
        ALL FIELDS
        WITH CORRESPONDING #( keys )
        RESULT DATA(entities).

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<entity>).

        IF ( <entity>-%is_draft = '00' ). " Saved
        ENDIF.

        IF ( <entity>-%is_draft = '01' ). " Draft

*           Select Actual Model
            SELECT SINGLE * FROM zi_model_005 WHERE ( ModelID = @<entity>-model ) INTO @DATA(wa_model).

*           Update Matrix Type
            MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Matrix
                UPDATE FIELDS ( MatrixTypeID )
                WITH VALUE #( (
                    %tky            = <entity>-%tky
                    MatrixTypeID    = wa_model-MatrixTypeID
                ) )
                FAILED DATA(ls_matrix_update_failed)
                MAPPED DATA(ls_matrix_update_mapped)
                REPORTED DATA(ls_matrix_update_reported).

        ENDIF.

    ENDLOOP.

  ENDMETHOD. " on_model_modify

  METHOD on_scheme_save. " on saving scheme (Model + Color + Matrix Type + Country) after modify
    DATA it_sizehead_create TYPE TABLE FOR CREATE zi_matrix_005\_Sizehead. " Size Head
    DATA it_size_create TYPE TABLE FOR CREATE zi_matrix_005\_Size. " Size

    DATA ls_sizehead1 TYPE zi_sizehead_005.
    DATA ls_sizehead2 TYPE zi_sizehead_005.

    DATA v_model        TYPE string VALUE ''.
    DATA v_color        TYPE string VALUE ''.
    DATA v_matrixtypeid TYPE string VALUE ''.
    DATA v_country      TYPE string VALUE ''.
    DATA v_update       TYPE string VALUE ''.

    DATA tabix TYPE sy-tabix.

   " Read transfered instances
    READ ENTITIES OF zi_matrix_005  IN LOCAL MODE
        ENTITY Matrix
        ALL FIELDS
        WITH CORRESPONDING #( keys )
        RESULT DATA(entities).

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<entity>).

*        APPEND VALUE #( %key = key-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success text = 'Event On Model.' ) ) TO reported-matrix.

        IF ( <entity>-%is_draft = '00' ). " Saved

            " Read and set Model, Color, MatrixTypeID, Country
            v_model         = <entity>-Model.
            v_color         = <entity>-Color.
            v_matrixtypeid  = <entity>-MatrixTypeID.
            v_country       = <entity>-Country.

*           (Re)Create Size Table according to Matrix Type :

*           Read Actual Matrix
            SELECT SINGLE * FROM zmatrix_005  WHERE ( matrixuuid = @<entity>-MatrixUUID ) INTO @DATA(wa_matrix).

*           Read Matrix Draft
            SELECT SINGLE * FROM zmatrix_005d WHERE ( matrixuuid = @<entity>-MatrixUUID ) INTO @DATA(wa_matrix_draft).

            wa_matrix_draft-model           = v_model.
            wa_matrix_draft-color           = v_color.
            wa_matrix_draft-matrixtypeid    = v_matrixtypeid.
            wa_matrix_draft-country         = v_country.

*           Set Matrix Type ID according to Model
            SELECT SINGLE * FROM zc_model_005 WHERE ( ModelID = @wa_matrix_draft-model ) INTO @DATA(wa_model).
            IF ( sy-subrc = 0 ).
                IF ( wa_matrix_draft-matrixtypeid <> wa_model-MatrixTypeID ).
                    wa_matrix_draft-matrixtypeid = wa_model-MatrixTypeID.
                    MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                        ENTITY Matrix
                        UPDATE FIELDS ( MatrixTypeID )
                        WITH VALUE #( (
                            %key            = <entity>-%key
                            MatrixTypeID    = wa_matrix_draft-MatrixTypeID
                        ) )
                        FAILED DATA(matrix_update_failed1)
                        MAPPED DATA(matrix_update_mapped1)
                        REPORTED DATA(matrix_update_reported1).
                ENDIF.
            ENDIF.

            IF ( ( wa_matrix-model = wa_matrix_draft-model ) AND ( wa_matrix-color = wa_matrix_draft-color ) AND ( wa_matrix-matrixtypeid = wa_matrix_draft-matrixtypeid ) AND ( wa_matrix-country = wa_matrix_draft-country ) ). " No change
                RETURN.
            ENDIF.

*           Read Actual Size Table
            READ ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Matrix
                BY \_Size
                ALL FIELDS WITH VALUE #( ( MatrixUUID = <entity>-MatrixUUID ) )
                RESULT DATA(lt_size)
                FAILED DATA(ls_size_read_failed)
                REPORTED DATA(ls_size_read_reported).

            SORT lt_size STABLE BY SizeID.

*           Delete Actual Size Table
            LOOP AT lt_size INTO DATA(ls_size).
                MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                    ENTITY Size
                    DELETE FROM VALUE #( ( MatrixUUID = <entity>-MatrixUUID SizeID = ls_size-SizeID ) )
                    FAILED DATA(ls_size_delete_failed)
                    MAPPED DATA(ls_size_delete_mapped)
                    REPORTED DATA(ls_size_delete_reported).
            ENDLOOP.

*           Choose Size Variant:
            DATA(hidden00) = abap_true.
            DATA(hidden01) = abap_true.
            DATA(hidden02) = abap_true.
            DATA(hidden03) = abap_true.
            DATA(hidden04) = abap_true.
            DATA(hidden05) = abap_true.
            DATA(hidden06) = abap_true.
            DATA(hidden07) = abap_true.
            DATA(hidden08) = abap_true.
            DATA(hidden09) = abap_true.
            DATA(hidden10) = abap_true.
            DATA(hidden11) = abap_true.
            DATA(hidden12) = abap_true.
            DATA(hidden13) = abap_true.
            DATA(hidden14) = abap_true.
            DATA(hidden15) = abap_true.
            DATA(hidden16) = abap_true.
            DATA(hidden17) = abap_true.
            DATA(hidden18) = abap_true.
            DATA(hidden19) = abap_true.
            DATA(hidden20) = abap_true.
            DATA(hidden21) = abap_true.

            IF ( v_matrixtypeid = 'SLIP' ).
                IF ( v_country = 'FR' ).
                    hidden01 = abap_false.
                ELSEIF ( v_country = 'US' ).
                    hidden02 = abap_false.
                ELSEIF ( v_country = 'GB' ).
                    hidden03 = abap_false.
                ELSE.
                    hidden04 = abap_false.
                ENDIF.
            ELSEIF ( v_matrixtypeid = 'INT' ).
                IF ( v_country = 'FR' ).
                    hidden05 = abap_false.
                ELSEIF ( v_country = 'US' ).
                    hidden06 = abap_false.
                ELSEIF ( v_country = 'GB' ).
                    hidden07 = abap_false.
                ELSE.
                    hidden08 = abap_false.
                ENDIF.
            ELSEIF ( v_matrixtypeid = 'BH' ).
                IF ( v_country = 'FR' ).
                    hidden09 = abap_false.
                ELSEIF ( v_country = 'US' ).
                    hidden10 = abap_false.
                ELSEIF ( v_country = 'GB' ).
                    hidden11 = abap_false.
                ELSE.
                    hidden12 = abap_false.
                ENDIF.
            ELSEIF ( v_matrixtypeid = 'BIKINI' ).
                IF ( v_country = 'FR' ).
                    hidden13 = abap_false.
                ELSEIF ( v_country = 'US' ).
                    hidden14 = abap_false.
                ELSEIF ( v_country = 'GB' ).
                    hidden15 = abap_false.
                ELSE.
                    hidden16 = abap_false.
                ENDIF.
            ELSEIF ( v_matrixtypeid = 'MIEDER' ).
                IF ( v_country = 'FR' ).
                    hidden17 = abap_false.
                ELSEIF ( v_country = 'US' ).
                    hidden18 = abap_false.
                ELSEIF ( v_country = 'GB' ).
                    hidden19 = abap_false.
                ELSE.
                    hidden20 = abap_false.
                ENDIF.
            ELSE. " OhneGr
                hidden21 = abap_false.
            ENDIF.

            MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Matrix
                UPDATE FIELDS ( Hidden00 Hidden01 Hidden02 Hidden03 Hidden04 Hidden05 Hidden06 Hidden07 Hidden08 Hidden09 Hidden10 Hidden11 Hidden12 Hidden13 Hidden14 Hidden15 Hidden16 Hidden17 Hidden18 Hidden19 Hidden20 Hidden21 )
                WITH VALUE #( (
                    %key     = <entity>-%key
                    Hidden00 = hidden00
                    Hidden01 = hidden01
                    Hidden02 = hidden02
                    Hidden03 = hidden03
                    Hidden04 = hidden04
                    Hidden05 = hidden05
                    Hidden06 = hidden06
                    Hidden07 = hidden07
                    Hidden08 = hidden08
                    Hidden09 = hidden09
                    Hidden10 = hidden10
                    Hidden11 = hidden11
                    Hidden12 = hidden12
                    Hidden13 = hidden13
                    Hidden14 = hidden14
                    Hidden15 = hidden15
                    Hidden16 = hidden16
                    Hidden17 = hidden17
                    Hidden18 = hidden18
                    Hidden19 = hidden19
                    Hidden20 = hidden20
                    Hidden21 = hidden21
                ) )
                FAILED DATA(matrix_update_failed2)
                MAPPED DATA(matrix_update_mapped2)
                REPORTED DATA(matrix_update_reported2).

*           Set Criticality01 according to Color Value

            DATA(criticality01) = '0'. " Grey

            CASE v_color.
                WHEN '047'.
                    criticality01 = '1'. " Red
                WHEN '048'.
                    criticality01 = '2'. " Yellow (Orange)
                WHEN '049'.
                    criticality01 = '3'. " Green
                WHEN '050'.
                    criticality01 = '5'. " Blue
            ENDCASE.

            MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Matrix
                UPDATE FIELDS ( Criticality01 )
                WITH VALUE #( (
                    %key     = <entity>-%key
                    Criticality01 = criticality01
                ) )
                FAILED DATA(matrix_update_failed3)
                MAPPED DATA(matrix_update_mapped3)
                REPORTED DATA(matrix_update_reported3).

*           Populate Size table according to Matrix Type and Country:

*           Read Matrix Type
            SELECT SINGLE * FROM zi_matrixtype_005 WHERE ( matrixtypeid = @wa_matrix_draft-matrixtypeid ) INTO @DATA(wa_matrixtype).

*           Read Matrix Type Table
            READ ENTITIES OF zi_matrixtype_005 " IN LOCAL MODE
                ENTITY MatrixType
                BY \_BackSize
                ALL FIELDS WITH VALUE #( ( MatrixTypeUUID = wa_matrixtype-matrixtypeuuid ) )
                RESULT DATA(lt_backsize)
                BY \_CupSize
                ALL FIELDS WITH VALUE #( ( MatrixTypeUUID = wa_matrixtype-matrixtypeuuid ) )
                RESULT DATA(lt_cupsize)
                FAILED DATA(ls_matrixtype_failed)
                REPORTED DATA(ls_matrixtype_reported).

            SORT lt_backsize STABLE BY Sort BackSizeID.
            SORT lt_cupsize STABLE BY Sort CupSizeID.

            LOOP AT lt_backsize INTO DATA(ls_backsize).
                tabix = sy-tabix.
                DATA(backSizeXX)    = ls_backsize-%data-BackSizeID.
                CASE wa_matrix_draft-country.
                    WHEN 'FR'.
                        backSizeXX = ls_backsize-%data-BackSizeFR.
                    WHEN 'US'.
                        backSizeXX = ls_backsize-%data-BackSizeUS.
                    WHEN 'GB'.
                        backSizeXX = ls_backsize-%data-BackSizeGB.
                ENDCASE.
                DATA(backSizeID)    = ls_backsize-%data-BackSizeID.
                CASE tabix.
                    WHEN 1.
                        ls_sizehead1-a = backSizeXX.
                        ls_sizehead2-a = backSizeID.
                    WHEN 2.
                        ls_sizehead1-b = backSizeXX.
                        ls_sizehead2-b = backSizeID.
                    WHEN 3.
                        ls_sizehead1-c = backSizeXX.
                        ls_sizehead2-c = backSizeID.
                    WHEN 4.
                        ls_sizehead1-d = backSizeXX.
                        ls_sizehead2-d = backSizeID.
                    WHEN 5.
                        ls_sizehead1-e = backSizeXX.
                        ls_sizehead2-e = backSizeID.
                    WHEN 6.
                        ls_sizehead1-f = backSizeXX.
                        ls_sizehead2-f = backSizeID.
                    WHEN 7.
                        ls_sizehead1-g = backSizeXX.
                        ls_sizehead2-g = backSizeID.
                    WHEN 8.
                        ls_sizehead1-h = backSizeXX.
                        ls_sizehead2-h = backSizeID.
                    WHEN 9.
                        ls_sizehead1-i = backSizeXX.
                        ls_sizehead2-i = backSizeID.
                    WHEN 10.
                        ls_sizehead1-j = backSizeXX.
                        ls_sizehead2-j = backSizeID.
                    WHEN 11.
                        ls_sizehead1-k = backSizeXX.
                        ls_sizehead2-k = backSizeID.
                    WHEN 12.
                        ls_sizehead1-l = backSizeXX.
                        ls_sizehead2-l = backSizeID.
                ENDCASE.
            ENDLOOP.

            APPEND VALUE #( MatrixUUID = <entity>-MatrixUUID
                %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID
                    SizeID      = 1
                    Back        = 'Back (label)'
                    a           = ls_sizehead1-a
                    b           = ls_sizehead1-b
                    c           = ls_sizehead1-c
                    d           = ls_sizehead1-d
                    e           = ls_sizehead1-e
                    f           = ls_sizehead1-f
                    g           = ls_sizehead1-g
                    h           = ls_sizehead1-h
                    i           = ls_sizehead1-i
                    j           = ls_sizehead1-j
                    k           = ls_sizehead1-k
                    l           = ls_sizehead1-l
                ) )
            ) TO it_sizehead_create.

            APPEND VALUE #( MatrixUUID = <entity>-MatrixUUID
                %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID
                    SizeID      = 2
                    Back        = 'Back (Id)'
                    a           = ls_sizehead2-a
                    b           = ls_sizehead2-b
                    c           = ls_sizehead2-c
                    d           = ls_sizehead2-d
                    e           = ls_sizehead2-e
                    f           = ls_sizehead2-f
                    g           = ls_sizehead2-g
                    h           = ls_sizehead2-h
                    i           = ls_sizehead2-i
                    j           = ls_sizehead2-j
                    k           = ls_sizehead2-k
                    l           = ls_sizehead2-l
                ) )
            ) TO it_sizehead_create.

*           Delete Obsolete Size Head Table
            MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Sizehead
                DELETE FROM VALUE #( ( MatrixUUID = <entity>-MatrixUUID SizeID = '1' ) )
                FAILED DATA(ls_sizehead_delete_failed1)
                MAPPED DATA(ls_sizehead_delete_mapped1)
                REPORTED DATA(ls_sizehead_delete_reported1).

            MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Sizehead
                DELETE FROM VALUE #( ( MatrixUUID = <entity>-MatrixUUID SizeID = '2' ) )
                FAILED DATA(ls_sizehead_delete_failed2)
                MAPPED DATA(ls_sizehead_delete_mapped2)
                REPORTED DATA(ls_sizehead_delete_reported2).

            " (Re)Create Actual Size Head Table
            MODIFY ENTITY IN LOCAL MODE zi_matrix_005
                CREATE BY \_Sizehead AUTO FILL CID
                FIELDS ( MatrixUUID SizeID Back a b c d e f g h i j k l BackSizeID )
                WITH it_sizehead_create
                FAILED DATA(ls_sizehead_create_failed)
                MAPPED DATA(ls_sizehead_create_mapped)
                REPORTED DATA(ls_sizehead_create_reported).

            IF ( lt_cupsize[] IS INITIAL ).
                APPEND VALUE #( CupSizeID = '0' ) TO lt_cupsize.
            ENDIF.
            LOOP AT lt_cupsize INTO DATA(ls_cupsize).
                tabix = sy-tabix.
                APPEND VALUE #( MatrixUUID = <entity>-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = tabix Back = ls_cupsize-CupSizeID BackSizeID = ls_cupsize-CupSizeID ) ) ) TO it_size_create.
            ENDLOOP.

*           Restore Size Table values from Item Table :

*           Read Item Table Draft
            SELECT * FROM zitem_005d WHERE ( matrixuuid = @<entity>-MatrixUUID )  ORDER BY itemid INTO TABLE @DATA(it_item_draft) .

            LOOP AT it_item_draft INTO DATA(wa_item_draft) WHERE ( draftentityoperationcode <> 'D' ).
                SPLIT wa_item_draft-product AT '-' INTO DATA(model) DATA(color) DATA(cupsize) DATA(backsize).
                IF ( ( model = wa_matrix_draft-model ) AND ( color = wa_matrix_draft-color ) ).
                    DATA(quantity) = wa_item_draft-quantity.
                    LOOP AT it_size_create INTO DATA(wa_size_create).
                        DATA(tabix1) = sy-tabix.
                        LOOP AT wa_size_create-%target INTO DATA(target).
                            DATA(tabix2) = sy-tabix.
                            IF ( cupsize = target-Back ).
                                CASE backsize.
                                    WHEN ls_sizehead2-a.
                                        target-a = quantity.
                                    WHEN ls_sizehead2-b.
                                        target-b = quantity.
                                    WHEN ls_sizehead2-c.
                                        target-c = quantity.
                                    WHEN ls_sizehead2-d.
                                        target-d = quantity.
                                    WHEN ls_sizehead2-e.
                                        target-e = quantity.
                                    WHEN ls_sizehead2-f.
                                        target-f = quantity.
                                    WHEN ls_sizehead2-g.
                                        target-g = quantity.
                                    WHEN ls_sizehead2-h.
                                        target-h = quantity.
                                    WHEN ls_sizehead2-i.
                                        target-i = quantity.
                                    WHEN ls_sizehead2-j.
                                        target-j = quantity.
                                    WHEN ls_sizehead2-k.
                                        target-k = quantity.
                                    WHEN ls_sizehead2-l.
                                        target-l = quantity.
                                ENDCASE.
                            ENDIF.
                            MODIFY wa_size_create-%target FROM target INDEX tabix2.
                        ENDLOOP.
                        MODIFY it_size_create FROM wa_size_create INDEX tabix1.
                    ENDLOOP.
                ENDIF.
            ENDLOOP.

            " (Re)Create Actual Size Table
            MODIFY ENTITY IN LOCAL MODE zi_matrix_005
              CREATE BY \_Size AUTO FILL CID
              FIELDS ( MatrixUUID SizeID Back a b c d e f g h i j k l BackSizeID )
              WITH it_size_create
              FAILED DATA(it_size_create_failed)
              MAPPED DATA(it_size_create_mapped)
              REPORTED DATA(it_size_create_reported).

*           Populate Size table according to Matrix Type


        ENDIF.

        IF ( <entity>-%is_draft = '01' ). " Draft

        ENDIF.

    ENDLOOP.

  ENDMETHOD. " on_scheme_save

  METHOD check_atp.

    DATA severity TYPE if_abap_behv_message=>t_severity VALUE if_abap_behv_message=>severity-success.
*    DATA msgty    TYPE sy-msgty VALUE 'S'.
    DATA msgno    TYPE sy-msgno VALUE '001'.
    DATA msgid    TYPE sy-msgid VALUE 'Z_MATRIX_005'.
    DATA msgv1    TYPE sy-msgv1 VALUE ''.
    DATA msgv2    TYPE sy-msgv1 VALUE ''.
    DATA msgv3    TYPE sy-msgv3 VALUE ''.
    DATA msgv4    TYPE sy-msgv3 VALUE ''.

    DATA plant              TYPE string VALUE '1000'.
    DATA product            TYPE string.
    DATA quantity           TYPE string.
    DATA stock              TYPE string.
    DATA available_stock    TYPE string.
    DATA availability       TYPE string.
    DATA criticality        TYPE string.

    " Read transfered instances
    READ ENTITIES OF zi_matrix_005  IN LOCAL MODE
        ENTITY Matrix
        ALL FIELDS
        WITH CORRESPONDING #( keys )
        RESULT DATA(entities).

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<entity>).

        IF ( <entity>-%is_draft = '00' ). " Saved
*           APPEND VALUE #( %key = key-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'ATP check - not yet implemented (saved mode).' ) ) TO reported-matrix.

            plant = <entity>-SalesOrganization.

*           Read Actual Item Table
            READ ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Matrix
                BY \_Item
                ALL FIELDS WITH VALUE #( ( MatrixUUID = <entity>-MatrixUUID ) )
                RESULT DATA(lt_item)
                FAILED DATA(ls_item_read_failed)
                REPORTED DATA(ls_item_read_reported).

            SORT lt_item STABLE BY ItemID DESCENDING.

            LOOP AT lt_item INTO DATA(ls_item).
                product     = CONV string( ls_item-Product ).
                quantity    = CONV string( ls_item-Quantity ).
                get_stock_availability( EXPORTING i_plant           = plant
                                                  i_product         = product
                                                  i_quantity        = quantity
                                        IMPORTING o_stock           = stock
                                                  o_available_stock = available_stock
                                                  o_availability    = availability
                                                  o_criticality     = criticality ).
                CLEAR msgv1.
                CLEAR msgv2.
                CLEAR msgv3.
                CLEAR msgv4.
                CASE availability.
                    WHEN 'No Product'.
                        severity    = if_abap_behv_message=>severity-error.
                        CONCATENATE 'No Product' product 'exists' INTO msgv1 SEPARATED BY space.
                    WHEN 'No Stock'.
                        severity    = if_abap_behv_message=>severity-error.
                        CONCATENATE 'No Stock for Product' product INTO msgv1 SEPARATED BY space.
                    WHEN 'Less'.
                        severity    = if_abap_behv_message=>severity-warning.
                        CONCATENATE 'Stock for Product' product '(' available_stock ')' INTO msgv1 SEPARATED BY space.
                        CONCATENATE 'is less than required quantity' quantity INTO msgv2 SEPARATED BY space.
                    WHEN 'Ok'.
                        severity    = if_abap_behv_message=>severity-success.
                        CONCATENATE 'Stock for Product' product '(' available_stock ')' INTO msgv1 SEPARATED BY space.
                        CONCATENATE 'is OK for required quantity' quantity INTO msgv2 SEPARATED BY space.
                ENDCASE.
                APPEND VALUE #( %key = <entity>-%key %msg = new_message( severity = severity id = msgid number = msgno v1 = msgv1 v2 = msgv2 v3 = msgv3 v4 = msgv4 ) ) TO reported-matrix.
*               Update the ATP values in items
                MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                    ENTITY Item
                    UPDATE FIELDS (
                        Stock
                        AvailableStock
                        Availability
                        Criticality01
                    )
                    WITH VALUE #( (
                        %key-MatrixUUID = ls_item-MatrixUUID
                        %key-ItemID     = ls_item-ItemID
                        Stock           = stock
                        AvailableStock  = available_stock
                        Availability    = availability
                        Criticality01   = criticality
                    ) )
                    MAPPED DATA(ls_update_mapped)
                    FAILED DATA(ls_update_failed)
                    REPORTED DATA(ls_update_reported).

            ENDLOOP.

        ENDIF.

        IF ( <entity>-%is_draft = '01' ). " Draft
           APPEND VALUE #( %key = <entity>-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Data not saved.' ) ) TO reported-matrix.
        ENDIF.
    ENDLOOP.

  ENDMETHOD. " check_atp

* For ATP Check
  METHOD get_stock_availability.

    DATA quantity           TYPE P DECIMALS 0.
    DATA confirmed          TYPE P DECIMALS 0.
    DATA stock              TYPE P DECIMALS 0.
    DATA available_stock    TYPE P DECIMALS 0.

*   Check Product
    SELECT SINGLE * FROM I_Product WHERE ( Product = @i_product ) INTO @DATA(wa_product).
    IF ( sy-subrc <> 0 ).
        o_stock             = ''.
        o_available_stock   = ''.
        o_availability      = 'No Product'.
        o_criticality       = '1'. " Red
    ELSE.
*       Check Product Stock
        SELECT
                *
            FROM
                I_MaterialStock
            WHERE
                ( Plant     = @i_plant ) AND
                ( Material  = @i_product )
            ORDER BY
                MatlDocLatestPostgDate
            INTO TABLE
                @DATA(it_material_stock).
        IF ( sy-subrc <> 0 ).
            o_stock             = ''.
            o_available_stock   = ''.
            o_availability      = 'No Stock'.
            o_criticality       = '1'. " Red
        ELSE.

*        DATA wmdvsx type standard table of bapiwmdvs.
*        DATA wmdvex type standard table of bapiwmdve.
*        CALL FUNCTION 'BAPI_MATERIAL_AVAILABILITY'
*          EXPORTING
*            plant              = '1000'
*            material           = i_product
*            unit               = '1000'
**            check_rule         =
**            stge_loc           =
**            batch              =
**            customer           =
**            doc_number         =
**            itm_number         =
**            wbs_elem           =
**            stock_ind          =
**            dec_for_rounding   =
**            dec_for_rounding_x =
**            read_atp_lock      =
**            read_atp_lock_x    =
**            material_evg       =
**            sgt_rcat           =
**            material_long      =
**            req_seg_long       =
**          IMPORTING
**            endleadtme         =
**            av_qty_plt         =
**            dialogflag         =
**            return             =
*          TABLES
*            wmdvsx             = wmdvsx[]
*            wmdvex             = wmdvex[]
**          .

*           Stock
            stock = 0.
            LOOP AT it_material_stock INTO DATA(wa_material_stock).
*               Posting Date
                DATA(matlDocLatestPostgDate)        = wa_material_stock-MatlDocLatestPostgDate.
*               Stock on Posting Date
                DATA(matlWrhsStkQtyInMatlBaseUnit)  = wa_material_stock-MatlWrhsStkQtyInMatlBaseUnit.
                stock = stock + CONV I( matlWrhsStkQtyInMatlBaseUnit ).
            ENDLOOP.
*           Confirmed
            SELECT * FROM I_SalesOrderItemTP WHERE ( Product = @i_product ) INTO TABLE @DATA(it_salesorderitem).
            confirmed = 0.
            LOOP AT it_salesorderitem  INTO DATA(wa_salesorderitem).
*               Check if delivered
                SELECT SINGLE
                        *
                    FROM
                        I_DeliveryDocumentItem
                    WHERE
                        ( ReferenceSDDocument       = @wa_salesorderitem-SalesOrder ) AND
                        ( ReferenceSDDocumentItem   = @wa_salesorderitem-SalesOrderItem )
                    INTO
                        @DATA(wa_deliverydocumentitem).
                DATA(goodsMovementStatus) = ''.
                IF ( sy-subrc = 0 ).
                    goodsMovementStatus = wa_deliverydocumentitem-GoodsMovementStatus.
                ENDIF.
                IF ( GoodsMovementStatus <> 'C'  ). " Completed
                    confirmed = confirmed + CONV I( wa_salesorderitem-ConfdDelivQtyInOrderQtyUnit ).
                ENDIF.
            ENDLOOP.
            available_stock = stock - confirmed.

            IF ( stock >= 0 ).
                o_stock = CONV string( stock ).
            ELSE.
                o_stock = '0'.
            ENDIF.
            IF ( available_stock >= 0 ).
                o_available_stock = CONV string( available_stock ).
            ELSE.
                o_available_stock = '0'.
            ENDIF.

*           Calculate Available
            quantity = CONV I( i_quantity ).
            IF ( available_stock < quantity ).
                o_availability = 'Less'.
                o_criticality  = '2'. " Yellow
            ELSE.
                o_availability = 'Ok'.
                o_criticality  = '3'. " Green
            ENDIF.

        ENDIF.
    ENDIF.

  ENDMETHOD. " get_stock_availability

  METHOD on_sales_order_create.
* Dummy method - to refresh Sales Order ID and Sales Order URL
  ENDMETHOD.

ENDCLASS. " lhc_matrix IMPLEMENTATION.

CLASS lsc_zi_matrix_005 DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

    METHODS new_message_with_text REDEFINITION.

    METHODS new_message REDEFINITION.

ENDCLASS.

CLASS lsc_zi_matrix_005 IMPLEMENTATION.

  METHOD save_modified.

    LOOP AT update-matrix INTO DATA(wa_matrix).

        IF ( ( wa_matrix-CreationDate IS NOT INITIAL ) AND ( wa_matrix-CreationTime IS NOT INITIAL ) AND ( wa_matrix-SalesOrderID IS INITIAL ) ).

            IF zbp_i_matrix_005=>mapped_sales_order IS NOT INITIAL.
                LOOP AT zbp_i_matrix_005=>mapped_sales_order-salesorder ASSIGNING FIELD-SYMBOL(<fs_so_mapped>).
                    CONVERT KEY OF i_salesordertp FROM <fs_so_mapped>-%pid TO DATA(ls_so_key).
                    <fs_so_mapped>-SalesOrder = ls_so_key-SalesOrder.
                    DATA(salesOrderID)  = ls_so_key-SalesOrder.
                    DATA(salesOrderURL) = |/ui#SalesOrder-manageV2&/SalesOrderManage('| && condense( val = |{ ls_so_key-SalesOrder ALPHA = OUT }| ) && |')|.
                    UPDATE zmatrix_005 SET SalesOrderID = @salesOrderID, SalesOrderURL = @salesOrderURL WHERE ( matrixuuid = @wa_matrix-MatrixUUID ).
                ENDLOOP.
            ENDIF.

        ENDIF.

    ENDLOOP.

  ENDMETHOD. " save_modified

  METHOD cleanup_finalize.
  ENDMETHOD.

  METHOD new_message.
  ENDMETHOD.

  METHOD new_message_with_text.
  ENDMETHOD.

ENDCLASS.
