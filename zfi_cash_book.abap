*&---------------------------------------------------------------------*
*& Report ZFI_CASH_BOOK
*&---------------------------------------------------------------------*
*& Description: Driver program for Cash Book Adobe Form
*& Logic: Fetches data from ACDOCA and Master tables based on logic provided
*&---------------------------------------------------------------------*
REPORT zfi_cash_book.

*----------------------------------------------------------------------*
* TABLES & DATA DECLARATIONS
*----------------------------------------------------------------------*
TABLES: acdoca.

DATA: gv_fm_name      TYPE rs38l_fnam,
      ls_docparams    TYPE sfpdocparams,
      ls_outputparams TYPE sfpoutputparams.

* Data structures for Form Interface
DATA: gs_header TYPE zfi_cash_book_hdr,
      gt_items  TYPE ztt_cash_book_itm,
      gs_item   LIKE LINE OF gt_items.

* Local variables for logic calculation
DATA: lv_banks        TYPE banks,
      lv_bankl        TYPE bankk,
      lv_opening_bal  TYPE hslxx,
      lv_run_bal      TYPE hslxx,
      lv_count        TYPE int4.

*----------------------------------------------------------------------*
* SELECTION SCREEN
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS: p_bukrs TYPE acdoca-rbukrs OBLIGATORY.
  PARAMETERS: p_hbkid TYPE acdoca-hbkid OBLIGATORY.
  PARAMETERS: p_hktid TYPE acdoca-hktid OBLIGATORY.
  SELECT-OPTIONS: s_budat FOR acdoca-budat OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* AT SELECTION-SCREEN ON VALUE-REQUEST (Custom F4 Help)
*----------------------------------------------------------------------*
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_hbkid.
  PERFORM f4_for_house_bank.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_hktid.
  PERFORM f4_for_account_id.

*----------------------------------------------------------------------*
* START-OF-SELECTION
*----------------------------------------------------------------------*
START-OF-SELECTION.

  PERFORM get_header_data.
  PERFORM get_opening_balance.
  PERFORM get_transaction_data.

  " Only print if data exists or user wants to see empty form with opening bal
  PERFORM call_adobe_form.

*&---------------------------------------------------------------------*
*& Form GET_HEADER_DATA
*&---------------------------------------------------------------------*
FORM get_header_data.

  " 1. Period Dates
  gs_header-company_code = p_bukrs.
  gs_header-period_from  = s_budat-low.
  gs_header-period_to    = s_budat-high.

  " 2. Account Number (T012K)
  SELECT SINGLE bankn
    FROM t012k
    INTO gs_header-account_num
    WHERE bukrs = p_bukrs
      AND hbkid = p_hbkid
      AND hktid = p_hktid.

  " 3. Account Title (T012T)
  SELECT SINGLE text1
    FROM t012t
    INTO gs_header-account_title
    WHERE bukrs = p_bukrs
      AND hbkid = p_hbkid
      AND hktid = p_hktid
      AND spras = sy-langu.

  " 4. Bank Name (T012 -> BNKA)
  " First get Bank Country and Key
  SELECT SINGLE banks bankl
    FROM t012
    INTO (lv_banks, lv_bankl)
    WHERE bukrs = p_bukrs
      AND hbkid = p_hbkid.

  IF sy-subrc = 0.
    " Then get Bank Name
    SELECT SINGLE banka
      FROM bnka
      INTO gs_header-bank_name
      WHERE banks = lv_banks
        AND bankl = lv_bankl.
  ENDIF.

  " Get Currency (assuming Company Code currency for simplicity)
  SELECT SINGLE waers FROM t001 INTO gs_header-currency WHERE bukrs = p_bukrs.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form GET_OPENING_BALANCE
*&---------------------------------------------------------------------*
FORM get_opening_balance.
  " Logic: Sum ACDOCA-HSL where date < From Date
  " Note: 01.01.1900 check is implicit as we are checking < s_budat-low

  SELECT SUM( hsl )
    FROM acdoca
    INTO lv_opening_bal
    WHERE rbukrs = p_bukrs
      AND hbkid  = p_hbkid
      AND hktid  = p_hktid
      AND budat  < s_budat-low
      AND rldnr  = '0L'. "Assuming Leading Ledger, adjust if needed

  gs_header-opening_bal = lv_opening_bal.
  lv_run_bal = lv_opening_bal. "Initialize running balance

ENDFORM.

*&---------------------------------------------------------------------*
*& Form GET_TRANSACTION_DATA
*&---------------------------------------------------------------------*
FORM get_transaction_data.
  " Local structure to hold joined data
  TYPES: BEGIN OF ty_acdoca_payr,
           budat TYPE acdoca-budat,
           sgtxt TYPE acdoca-sgtxt,
           hsl   TYPE acdoca-hsl,
           rhcur TYPE acdoca-rhcur,
           chect TYPE payr-chect, " Cheque Number from PAYR
         END OF ty_acdoca_payr.

  DATA: lt_data TYPE TABLE OF ty_acdoca_payr,
        ls_data TYPE ty_acdoca_payr.

  " Fetch Line Items and Join with PAYR for Cheque Number
  " Logic: PAYR-ZBUKR = BUKRS, PAYR-HBKID = HBKID, PAYR-HKTID = HKTID, PAYR-VBLNR = BELNR
  SELECT a~budat, a~sgtxt, a~hsl, a~rhcur, p~chect
    FROM acdoca AS a
    LEFT OUTER JOIN payr AS p ON  p~zbukr = a~rbukrs
                              AND p~hbkid = a~hbkid
                              AND p~hktid = a~hktid
                              AND p~vblnr = a~belnr
    INTO TABLE @lt_data
    WHERE a~rbukrs = @p_bukrs
      AND a~budat  IN @s_budat
      AND a~hbkid  = @p_hbkid
      AND a~hktid  = @p_hktid
      AND a~rldnr  = '0L'
      AND a~augbl  = @space
    ORDER BY a~budat, a~belnr, a~docln.

  " Initialize Totals
  CLEAR: gs_header-total_receipt, gs_header-total_payment.
  lv_count   = 1.
  lv_run_bal = gs_header-opening_bal.

  LOOP AT lt_data INTO ls_data.
    CLEAR gs_item.

    gs_item-sr_no       = lv_count.
    gs_item-trans_date  = ls_data-budat.
    gs_item-particulars = ls_data-sgtxt.
    gs_item-currency    = ls_data-rhcur.
    gs_item-chect       = ls_data-chect. " Pass Cheque Number to output

    " Calculate Totals & Split Receipt/Payment
    IF ls_data-hsl >= 0.
      gs_item-receipt = ls_data-hsl.
      ADD gs_item-receipt TO gs_header-total_receipt.
    ELSE.
      gs_item-payment = abs( ls_data-hsl ).
      ADD gs_item-payment TO gs_header-total_payment.
    ENDIF.

    " Calculate Running Balance
    lv_run_bal = lv_run_bal + ls_data-hsl.
    gs_item-balance = lv_run_bal.

    APPEND gs_item TO gt_items.
    lv_count = lv_count + 1.
  ENDLOOP.

  gs_header-closing_bal = lv_run_bal.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form CALL_ADOBE_FORM
*&---------------------------------------------------------------------*
FORM call_adobe_form.
  " 1. Set Output Parameters (Print Preview)
  ls_outputparams-nodialog = 'X'.
  ls_outputparams-preview = 'X'.
  ls_outputparams-dest    = 'LP01'.

  CALL FUNCTION 'FP_JOB_OPEN'
    CHANGING
      ie_outputparams = ls_outputparams
    EXCEPTIONS
      cancel          = 1
      usage_error     = 2
      system_error    = 3
      internal_error  = 4
      OTHERS          = 5.

  " 2. Get Function Module Name generated for the Form
  " Replace 'ZFI_CASH_BOOK' with your actual SFP Form Name
  CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
    EXPORTING
      i_name     = 'ZFI_CASH_BOOK'
    IMPORTING
      e_funcname = gv_fm_name.

  " 3. Call The Form
  CALL FUNCTION gv_fm_name
    EXPORTING
      /1bcdwb/docparams = ls_docparams
      is_header         = gs_header
      it_items          = gt_items
    EXCEPTIONS
      usage_error       = 1
      system_error      = 2
      internal_error    = 3
      OTHERS            = 4.

  CALL FUNCTION 'FP_JOB_CLOSE'
    EXCEPTIONS
      usage_error    = 1
      system_error   = 2
      internal_error = 3
      OTHERS         = 4.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F4_FOR_HOUSE_BANK
*&---------------------------------------------------------------------*
FORM f4_for_house_bank.
  DATA: lt_dynpfields  TYPE TABLE OF dynpread,
        ls_dynpfield   TYPE dynpread.

  " Read the Company Code directly from the screen UI
  ls_dynpfield-fieldname = 'P_BUKRS'.
  APPEND ls_dynpfield TO lt_dynpfields.

  CALL FUNCTION 'DYNP_VALUES_READ'
    EXPORTING
      dyname     = sy-repid
      dynumb     = sy-dynnr
    TABLES
      dynpfields = lt_dynpfields
    EXCEPTIONS
      OTHERS     = 1.

  READ TABLE lt_dynpfields INTO ls_dynpfield WITH KEY fieldname = 'P_BUKRS'.

  IF sy-subrc = 0 AND ls_dynpfield-fieldvalue IS NOT INITIAL.
    " FIXED: Changed bankk to bankl
    SELECT hbkid, bankl
      FROM t012
      INTO TABLE @DATA(lt_house_banks)
      WHERE bukrs = @ls_dynpfield-fieldvalue.

    " Display the popup
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        retfield        = 'HBKID'
        dynpprog        = sy-repid
        dynpnr          = sy-dynnr
        dynprofield     = 'P_HBKID'
        value_org       = 'S'
      TABLES
        value_tab       = lt_house_banks
      EXCEPTIONS
        OTHERS          = 1.
  ELSE.
    MESSAGE 'Please enter a Company Code first.' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form F4_FOR_ACCOUNT_ID
*&---------------------------------------------------------------------*
FORM f4_for_account_id.
  DATA: lt_dynpfields  TYPE TABLE OF dynpread,
        ls_dynpfield   TYPE dynpread,
        lv_bukrs       TYPE bukrs,
        lv_hbkid       TYPE hbkid.

  " Read both BUKRS and HBKID from the screen UI
  ls_dynpfield-fieldname = 'P_BUKRS'. APPEND ls_dynpfield TO lt_dynpfields.
  ls_dynpfield-fieldname = 'P_HBKID'. APPEND ls_dynpfield TO lt_dynpfields.

  CALL FUNCTION 'DYNP_VALUES_READ'
    EXPORTING
      dyname     = sy-repid
      dynumb     = sy-dynnr
    TABLES
      dynpfields = lt_dynpfields
    EXCEPTIONS
      OTHERS     = 1.

  READ TABLE lt_dynpfields INTO ls_dynpfield WITH KEY fieldname = 'P_BUKRS'.
  IF sy-subrc = 0. lv_bukrs = ls_dynpfield-fieldvalue. ENDIF.

  READ TABLE lt_dynpfields INTO ls_dynpfield WITH KEY fieldname = 'P_HBKID'.
  IF sy-subrc = 0. lv_hbkid = ls_dynpfield-fieldvalue. ENDIF.

  IF lv_bukrs IS NOT INITIAL AND lv_hbkid IS NOT INITIAL.
    " FIXED: Changed text1 to bankn (Account Number)
    SELECT hktid, bankn
      FROM t012k
      INTO TABLE @DATA(lt_account_ids)
      WHERE bukrs = @lv_bukrs
        AND hbkid = @lv_hbkid.

    " Display the popup
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        retfield        = 'HKTID'
        dynpprog        = sy-repid
        dynpnr          = sy-dynnr
        dynprofield     = 'P_HKTID'
        value_org       = 'S'
      TABLES
        value_tab       = lt_account_ids
      EXCEPTIONS
        OTHERS          = 1.
  ELSE.
    MESSAGE 'Please enter Company Code and House Bank first.' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.
