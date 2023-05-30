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

    METHODS on_model FOR DETERMINE ON SAVE " on model/color
      IMPORTING keys FOR matrix~on_model.

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

    DATA it_matrix TYPE TABLE FOR UPDATE zi_matrix_005. " Matrix

    LOOP AT keys INTO DATA(key).

        IF ( key-%is_draft = '00' ). " Saved

            SELECT SINGLE * FROM zi_matrix_005 WHERE ( MatrixUUID = @key-MatrixUUID ) INTO @DATA(wa_matrix_005).
            IF ( sy-subrc <> 0 ).
                RETURN.
            ENDIF.
            SELECT SINGLE
                    *
                FROM
                    i_salesordertp
                WHERE
                    ( CreationDate = @wa_matrix_005-CreationDate ) AND
                    ( CreationTime = @wa_matrix_005-CreationTime )
                INTO
                    @DATA(wa_i_salesordertp).

            IF ( sy-subrc <> 0 ).

                APPEND VALUE #( %key = key-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Sales Order not created yet.' ) ) TO reported-matrix.

            ELSE.

                DATA(salesOrderURL) = |/ui#SalesOrder-manageV2&/SalesOrderManage('| && condense( val = |{ wa_i_salesordertp-SalesOrder ALPHA = OUT }| ) && |')|.
                "DATA(salesOrderURL) = '/ui#SalesDocument-display?sap-ui-tech-hint=GUI&SalesDocument=' && wa_i_salesordertp-SalesOrder. " old version on VA03

*               Sales Order ID
                it_matrix = VALUE #( (
                    %tky            = key-%tky
                    SalesOrderID    = wa_i_salesordertp-SalesOrder
                    SalesOrderURL   = salesOrderURL

                ) ).

*               Update Matrix (Sales Order ID)
                MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                    ENTITY Matrix
                    UPDATE FIELDS ( SalesOrderID SalesOrderURL )
                    WITH it_matrix
                    FAILED DATA(it_failed)
                    MAPPED DATA(it_mapped)
                    REPORTED DATA(it_reported).

*               Restore Items from Sales Order :

*               Read Actual Matrix Items
                READ ENTITIES OF zi_matrix_005 IN LOCAL MODE
                    ENTITY Matrix
                    BY \_Item
                    ALL FIELDS WITH VALUE #( ( MatrixUUID = key-MatrixUUID ) )
                    RESULT DATA(lt_matrix_item)
                    FAILED DATA(ls_read_failed)
                    REPORTED DATA(ls_read_reported).

                SORT lt_matrix_item STABLE BY ItemID.

*               Delete Actual Matrix Items
                LOOP AT lt_matrix_item INTO DATA(ls_matrix_item).
                    MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                        ENTITY Item
                        DELETE FROM VALUE #( ( MatrixUUID = key-MatrixUUID ItemID = ls_matrix_item-ItemID ) )
                        FAILED DATA(ls_delete_failed)
                        MAPPED DATA(ls_delete_mapped)
                        REPORTED DATA(ls_delete_reported).
                ENDLOOP.

*               Read Sales Order Items
                READ ENTITIES OF i_salesordertp
                    ENTITY SalesOrder
                    BY \_Item
                    ALL FIELDS WITH VALUE #( ( salesorder = wa_i_salesordertp-SalesOrder ) )
                    RESULT DATA(lt_salesorder_item)
                    FAILED DATA(ls_failed_read)
                    REPORTED DATA(ls_reported_read).

                SORT lt_salesorder_item STABLE BY SalesOrderItem.

*               Create New Matrix Items
                LOOP AT lt_salesorder_item INTO DATA(ls_salesorder_item).
                    DATA(product)   = ls_salesorder_item-product.
                    DATA(quantity)  = ls_salesorder_item-RequestedQuantity.
                    SPLIT product AT '-' INTO DATA(model) DATA(color) DATA(cupsize) DATA(backsize).
                    MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                        ENTITY Matrix
                        CREATE BY \_Item
                        FIELDS ( ItemID Model Color Cupsize Backsize Product Quantity )
                        WITH VALUE #( (
                            MatrixUUID = key-MatrixUUID
                            %target = VALUE #( (
                                %cid       = sy-tabix
                                ItemID     = sy-tabix
                                Model      = model
                                Color      = color
                                Cupsize    = cupsize
                                Backsize   = backsize
                                Product    = product
                                Quantity   = quantity
                            ) )
                        ) )
                        FAILED DATA(ls_item_failed)
                        MAPPED DATA(ls_item_mapped)
                        REPORTED DATA(ls_item_reported).
                ENDLOOP.

            ENDIF.

        ENDIF.

        IF ( key-%is_draft = '01' ). " Draft
            APPEND VALUE #( %key = key-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Data not saved.' ) ) TO reported-matrix.
        ENDIF.

    ENDLOOP.

  ENDMETHOD. " get_sales_order

  METHOD on_create. " on initial create

    DATA it_matrix TYPE TABLE FOR UPDATE zi_matrix_005. " Matrix
    DATA it_size TYPE TABLE FOR CREATE zi_matrix_005\_Size. " Size

    LOOP AT keys INTO DATA(key).

*       New Matrix ID
        DATA matrixid TYPE zi_matrix_005-MatrixID VALUE '0000000000'.
        SELECT MAX( matrixid ) FROM zi_matrix_005 INTO (@matrixid).
        matrixid  = ( matrixid + 1 ).

*       Default Values :
        it_matrix = VALUE #( (
            %tky                    = key-%tky
            MatrixID                = matrixid
            SalesOrderType          = 'OR'
            SalesOrganization       = '1010'
            DistributionChannel     = '10'
            OrganizationDivision    = '00'
            SoldToParty             = '0010100014'
        ) ).

*       Update Matrix
        MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
            ENTITY Matrix
            UPDATE FIELDS ( MatrixID SalesOrderType SalesOrganization DistributionChannel OrganizationDivision SoldToParty )
            WITH it_matrix
            FAILED DATA(it_failed)
            MAPPED DATA(it_mapped)
            REPORTED DATA(it_reported).

    ENDLOOP.

*   Create Size Table:

*   Read Matrix
    READ ENTITIES OF zi_matrix_005 IN LOCAL MODE
        ENTITY Matrix
        FROM VALUE #( ( %tky = key-%tky ) )
        RESULT DATA(it_matrix_result)
        REPORTED DATA(it_matrix_reported).

    LOOP AT it_matrix_result INTO DATA(wa_matrix_result).

*       Populate the size table (field Back only)
        APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
            MatrixUUID = wa_matrix_result-MatrixUUID SizeID = 1 Back = '060' ) ) ) TO it_size.
        APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
            MatrixUUID = wa_matrix_result-MatrixUUID SizeID = 2 Back = '065' ) ) ) TO it_size.
        APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
            MatrixUUID = wa_matrix_result-MatrixUUID SizeID = 3 Back = '070' ) ) ) TO it_size.
        APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
            MatrixUUID = wa_matrix_result-MatrixUUID SizeID = 4 Back = '075' ) ) ) TO it_size.
        APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
            MatrixUUID = wa_matrix_result-MatrixUUID SizeID = 5 Back = '080' ) ) ) TO it_size.
        APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
            MatrixUUID = wa_matrix_result-MatrixUUID SizeID = 6 Back = '085' ) ) ) TO it_size.
        APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
            MatrixUUID = wa_matrix_result-MatrixUUID SizeID = 7 Back = '090' ) ) ) TO it_size.

        " Create Size Table
        MODIFY ENTITY IN LOCAL MODE zi_matrix_005
          CREATE BY \_Size AUTO FILL CID
          FIELDS ( MatrixUUID SizeID Back )
          WITH it_size
          FAILED DATA(it_size_failed)
          MAPPED DATA(it_size_mapped)
          REPORTED DATA(it_size_reported).

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

    DATA model      TYPE string.
    DATA color      TYPE string.
    DATA cupsize    TYPE string.
    DATA backsize   TYPE string.
    DATA product    TYPE string.
    DATA quantity   TYPE string.

    LOOP AT keys INTO DATA(key).

        APPEND VALUE #( %key = key-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success text = 'Activate.' ) ) TO reported-matrix.

*       Read Actual Matrix
        SELECT SINGLE * FROM zmatrix_005  WHERE ( matrixuuid = @key-MatrixUUID ) INTO @DATA(wa_matrix).

*       Read Matrix Draft
        SELECT SINGLE * FROM zmatrix_005d WHERE ( matrixuuid = @key-MatrixUUID ) INTO @DATA(wa_matrix_draft).

        IF ( wa_matrix-soldtoparty <> wa_matrix_draft-soldtoparty ).
            DATA(customerURL) = |/ui#Customer-displayFactSheet?sap-ui-tech-hint=GUI&/C_CustomerOP('| && condense( val = |{ wa_matrix_draft-soldtoparty ALPHA = OUT }| ) && |')|.
            MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Matrix
                UPDATE FIELDS ( CustomerURL )
                WITH VALUE #( (
                    %key        = key-%key
                    CustomerURL = customerURL
                ) ).
        ENDIF.

*       If model/color changed - do not generate items
        IF ( ( wa_matrix-model <> wa_matrix_draft-model ) OR ( wa_matrix-color <> wa_matrix_draft-color ) ).
            RETURN.
        ENDIF.

*       Read the whole Matrix (root)
*        SELECT SINGLE * FROM zc_matrix_005 WHERE ( MatrixUUID = @key-MatrixUUID ) INTO @DATA(wa_matrix).

*       Read the whole Size table
*        SELECT * FROM zc_size_005 WHERE ( MatrixUUID = @key-MatrixUUID ) ORDER By back INTO TABLE @DATA(it_size).
*       Read Size Table (Draft)
        SELECT * FROM zsize_005d WHERE ( MatrixUUID = @key-MatrixUUID ) ORDER By back INTO TABLE @DATA(it_size).

*       Find max item id
*        SELECT MAX( ItemID ) FROM zc_item_005 WHERE ( MatrixUUID = @key-MatrixUUID ) INTO @DATA(maxid).
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

*       Add New Items based on Actual Size table
        LOOP AT it_size INTO DATA(wa_size).
            IF ( wa_size-a IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = wa_size-Back.
                cupsize     = 'A'.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
                quantity    = wa_size-a.
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
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-b IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = wa_size-Back.
                cupsize     = 'B'.
                quantity    = wa_size-b.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
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
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-c IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = wa_size-Back.
                cupsize     = 'C'.
                quantity    = wa_size-c.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
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
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-d IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = wa_size-Back.
                cupsize     = 'D'.
                quantity    = wa_size-d.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
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
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-e IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = wa_size-Back.
                cupsize     = 'E'.
                quantity    = wa_size-e.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
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
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-f IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = wa_size-Back.
                cupsize     = 'F'.
                quantity    = wa_size-f.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
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
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-g IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = wa_size-Back.
                cupsize     = 'G'.
                quantity    = wa_size-g.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
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
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-h IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = wa_size-Back.
                cupsize     = 'H'.
                quantity    = wa_size-h.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
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
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.
            IF ( wa_size-i IS NOT INITIAL ).
                maxid = maxid + 1.
                cid = maxid.
                backsize    = wa_size-Back.
                cupsize     = 'I'.
                quantity    = wa_size-i.
                product     = model && '-' && color && '-' && cupsize && '-' && backsize.
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
                    ) )
                ).
                APPEND wa_item_create TO it_item_create.
            ENDIF.

            " Create New Items
            MODIFY ENTITY IN LOCAL MODE zi_matrix_005
              CREATE BY \_Item AUTO FILL CID
              FIELDS ( ItemID MatrixUUID Model Color Backsize Cupsize Product Quantity )
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
                ) )
            ) TO it_item_create.
        ENDLOOP.

        " Create New (renumbered) Items
        MODIFY ENTITY IN LOCAL MODE zi_matrix_005
          CREATE BY \_Item AUTO FILL CID
          FIELDS ( ItemID MatrixUUID Model Color Backsize Cupsize Product Quantity )
          WITH it_item_create
          FAILED DATA(ls_create_failed2)
          MAPPED DATA(ls_create_mapped2)
          REPORTED DATA(ls_create_reported2).

    ENDLOOP.

    " Finally, do refresh (Side Effect on _Item)

  ENDMETHOD. " Activate

  METHOD on_model. " on saving changed model/color

    DATA it_size_create TYPE TABLE FOR CREATE zi_matrix_005\_Size. " Size

    LOOP AT keys INTO DATA(key).

*        APPEND VALUE #( %key = key-%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success text = 'Event On Model.' ) ) TO reported-matrix.

*       Adjust Model/Color (alpha-conversion) :

        DATA v_model  TYPE string VALUE ''.
        DATA v_color  TYPE string VALUE ''.
        DATA v_update TYPE string VALUE ''.

       " Read transfered instances
        READ ENTITIES OF zi_matrix_005  IN LOCAL MODE
            ENTITY Matrix
            FIELDS ( Model Color )
            WITH CORRESPONDING #( keys )
            RESULT DATA(entities).

        " Read and set Model, Color
        LOOP AT entities ASSIGNING FIELD-SYMBOL(<entity>).
            v_model = <entity>-Model.
            v_color = <entity>-Color.
            IF ( v_model CO '1234567890' ). " contains only
                DO.
                    IF ( STRLEN( v_model ) < 7 ).
                        v_model = '0' && v_model.
                    ELSE.
                        EXIT.
                    ENDIF.
                ENDDO.
                IF ( <entity>-Model <> v_model ).
                    <entity>-Model = v_model.
                    v_update = 'X'.
                ENDIF.
            ENDIF.
            IF ( v_color CO '1234567890' ). " contains only
                DO 3 TIMES.
                    IF ( STRLEN( v_color ) < 3 ).
                        v_color = '0' && v_color.
                    ELSE.
                        EXIT.
                    ENDIF.
                ENDDO.
                IF ( <entity>-Color <> v_color ).
                    <entity>-Color = v_color.
                    v_update = 'X'.
                ENDIF.
            ENDIF.
        ENDLOOP.

        " Update instances
        IF ( v_update = 'X' ).
            MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Matrix
                UPDATE FIELDS ( Model Color )
                WITH VALUE #( FOR entity IN entities INDEX INTO i (
                    %tky     = entity-%tky
                    Model    = entity-Model
                    Color    = entity-Color
                ) ).
        ENDIF.

*       (Re)Create Size Table according to Model :

*       Read Actual Matrix
        SELECT SINGLE * FROM zmatrix_005  WHERE ( matrixuuid = @key-MatrixUUID ) INTO @DATA(wa_matrix).

*       Read Matrix Draft
        SELECT SINGLE * FROM zmatrix_005d WHERE ( matrixuuid = @key-MatrixUUID ) INTO @DATA(wa_matrix_draft).

        wa_matrix_draft-model = <entity>-Model.
        wa_matrix_draft-color = <entity>-Color.

        IF ( ( wa_matrix-model = wa_matrix_draft-model ) AND ( wa_matrix-color = wa_matrix_draft-color ) ). " No Model/Color change
            RETURN.
        ENDIF.

*       Read Actual Size Table
        READ ENTITIES OF zi_matrix_005 IN LOCAL MODE
            ENTITY Matrix
            BY \_Size
            ALL FIELDS WITH VALUE #( ( MatrixUUID = key-MatrixUUID ) )
            RESULT DATA(lt_size)
            FAILED DATA(ls_read_failed)
            REPORTED DATA(ls_read_reported).

        SORT lt_size STABLE BY SizeID.

*       Delete Actual Size Table
        LOOP AT lt_size INTO DATA(ls_size).
            MODIFY ENTITIES OF zi_matrix_005 IN LOCAL MODE
                ENTITY Size
                DELETE FROM VALUE #( ( MatrixUUID = key-MatrixUUID SizeID = ls_size-SizeID ) )
                FAILED DATA(ls_delete_failed)
                MAPPED DATA(ls_delete_mapped)
                REPORTED DATA(ls_delete_reported).
        ENDLOOP.

*       Populate Size table according to Model/Color
        DATA(modelcolor) = wa_matrix_draft-Model && '-' && wa_matrix_draft-Color.
        CASE modelcolor.
            WHEN 'TG000232-048'. " featured
                APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = 1 Back = '065' ) ) ) TO it_size_create.
                APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = 2 Back = '070' ) ) ) TO it_size_create.
                APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = 3 Back = '075' ) ) ) TO it_size_create.
                APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = 4 Back = '080' ) ) ) TO it_size_create.
            WHEN 'TG000233-048'. " featured
                APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = 1 Back = '060' ) ) ) TO it_size_create.
                APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = 2 Back = '070' ) ) ) TO it_size_create.
                APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = 3 Back = '080' ) ) ) TO it_size_create.
                APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = 4 Back = '090' ) ) ) TO it_size_create.
            WHEN OTHERS. " default
                APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = 1 Back = '060' ) ) ) TO it_size_create.
                APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = 2 Back = '065' ) ) ) TO it_size_create.
                APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = 3 Back = '070' ) ) ) TO it_size_create.
                APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = 4 Back = '075' ) ) ) TO it_size_create.
                APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = 5 Back = '080' ) ) ) TO it_size_create.
                APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = 6 Back = '085' ) ) ) TO it_size_create.
                APPEND VALUE #( MatrixUUID = key-MatrixUUID %target = VALUE #( (
                    MatrixUUID = wa_matrix_draft-MatrixUUID SizeID = 7 Back = '090' ) ) ) TO it_size_create.
        ENDCASE.

*       Restore Size Table values from Item Table :

*       Read Actual Item Table
        SELECT * FROM zitem_005  WHERE ( matrixuuid = @key-MatrixUUID ) INTO TABLE @DATA(it_item).

*       Read Item Table Draft
        SELECT * FROM zitem_005d WHERE ( matrixuuid = @key-MatrixUUID ) INTO TABLE @DATA(it_item_draft).

        LOOP AT it_item_draft INTO DATA(wa_item_draft) WHERE ( draftentityoperationcode <> 'D' ).
            SPLIT wa_item_draft-product AT '-' INTO DATA(model) DATA(color) DATA(cupsize) DATA(backsize).
            IF ( ( model = wa_matrix_draft-model ) AND ( color = wa_matrix_draft-color ) ).
                DATA(quantity) = wa_item_draft-quantity.
                LOOP AT it_size_create INTO DATA(wa_size_create).
                    DATA(tabix1) = sy-tabix.
                    LOOP AT wa_size_create-%target INTO DATA(target).
                        DATA(tabix2) = sy-tabix.
                        IF ( backsize = target-Back ).
                            CASE cupsize.
                                WHEN 'A'. target-a = quantity.
                                WHEN 'B'. target-b = quantity.
                                WHEN 'C'. target-c = quantity.
                                WHEN 'D'. target-d = quantity.
                                WHEN 'E'. target-e = quantity.
                                WHEN 'F'. target-f = quantity.
                                WHEN 'G'. target-g = quantity.
                                WHEN 'H'. target-h = quantity.
                                WHEN 'I'. target-i = quantity.
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
          FIELDS ( MatrixUUID SizeID Back a b c d e f g h i )
          WITH it_size_create
          FAILED DATA(it_size_failed)
          MAPPED DATA(it_size_mapped)
          REPORTED DATA(it_size_reported).

    ENDLOOP.

  ENDMETHOD. " on_model

ENDCLASS. " lhc_matrix IMPLEMENTATION.
