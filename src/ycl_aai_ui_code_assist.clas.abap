CLASS ycl_aai_ui_code_assist DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS: mc_display_mode_dock   TYPE c LENGTH 10 VALUE 'DOCK',
               mc_display_mode_dialog TYPE c LENGTH 10 VALUE 'DIALOG',
               mc_display_mode_custom TYPE c LENGTH 10 VALUE 'CUSTOM'.

    DATA: mo_dock             TYPE REF TO cl_gui_docking_container,
          mo_dialogbox        TYPE REF TO cl_gui_dialogbox_container,
          mo_splitter         TYPE REF TO cl_gui_splitter_container,
          mo_abapeditor       TYPE REF TO cl_gui_abapedit,
          mo_textedit         TYPE REF TO cl_gui_textedit,
          mo_toolbar          TYPE REF TO cl_gui_toolbar,
          mo_custom_container TYPE REF TO cl_gui_custom_container.

    DATA: mt_buffer TYPE rswsourcet.

    METHODS constructor
      IMPORTING
        i_display_mode      TYPE csequence DEFAULT mc_display_mode_dock
        io_api              TYPE REF TO yif_aai_chat OPTIONAL
        io_custom_container TYPE REF TO cl_gui_custom_container OPTIONAL.

    METHODS run.

    METHODS on_function_selected FOR EVENT function_selected OF cl_gui_toolbar
      IMPORTING fcode.

    METHODS on_close FOR EVENT close OF cl_gui_dialogbox_container.

    METHODS set_api
      IMPORTING
        io_api TYPE REF TO yif_aai_chat.

    METHODS set_prompt_template
      IMPORTING
        io_prompt_template TYPE REF TO yif_aai_prompt_template.

    METHODS set_popup_size
      IMPORTING
        i_height TYPE i
        i_width  TYPE i.

    METHODS set_abap_editor_integ_on.

    METHODS set_abap_editor_integ_off.

    METHODS free.


  PROTECTED SECTION.

  PRIVATE SECTION.

    DATA: _o_api             TYPE REF TO yif_aai_chat,
          _o_prompt_template TYPE REF TO yif_aai_prompt_template.

    DATA: _display_mode            TYPE c LENGTH 10 VALUE mc_display_mode_dock,
          _popup_height            TYPE i VALUE 400,
          _popup_width             TYPE i VALUE 400,
          _abap_editor_integration TYPE abap_bool VALUE abap_true.

    METHODS _render.

    METHODS _handle_send_message.

    METHODS _get_abap_editor_context
      RETURNING VALUE(r_context) TYPE string.

    METHODS _insert_code_block.

    METHODS _reset.

ENDCLASS.



CLASS ycl_aai_ui_code_assist IMPLEMENTATION.


  METHOD constructor.

    IF i_display_mode IS SUPPLIED.

      CASE i_display_mode.

        WHEN mc_display_mode_dock.

          me->_display_mode = mc_display_mode_dock.

        WHEN mc_display_mode_dialog.

          me->_display_mode = mc_display_mode_dialog.

        WHEN OTHERS.

          me->_display_mode = mc_display_mode_dock. " Set Default

      ENDCASE.

    ENDIF.

    IF io_api IS SUPPLIED AND io_api IS BOUND.

      me->_o_api = io_api.

    ENDIF.

    IF io_custom_container IS SUPPLIED AND io_custom_container IS BOUND.

      me->mo_custom_container = io_custom_container.

      me->_display_mode = mc_display_mode_custom.

    ENDIF.

    me->_o_prompt_template = NEW ycl_aai_prompt_template( |User question: %USER_MESSAGE% \n\nCode Block:\n\n %CONTEXT% | ).

  ENDMETHOD.


  METHOD free.

    IF me->mo_abapeditor IS BOUND.

      me->mo_abapeditor->free(
        EXCEPTIONS
          cntl_error        = 0
          cntl_system_error = 0
          OTHERS            = 0
      ).

    ENDIF.

    IF me->mo_textedit IS BOUND.

      me->mo_textedit->free(
        EXCEPTIONS
          cntl_error        = 0
          cntl_system_error = 0
          OTHERS            = 0
      ).

    ENDIF.

    IF me->mo_toolbar IS BOUND.

      me->mo_toolbar->free(
        EXCEPTIONS
          cntl_error        = 0
          cntl_system_error = 0
          OTHERS            = 0
      ).

    ENDIF.

    IF me->mo_splitter IS BOUND.

      me->mo_splitter->free(
        EXCEPTIONS
          cntl_error        = 0
          cntl_system_error = 0
          OTHERS            = 0
      ).

    ENDIF.

    IF me->mo_dock IS BOUND.

      me->mo_dock->free(
        EXCEPTIONS
          cntl_error        = 0
          cntl_system_error = 0
          OTHERS            = 0
      ).

    ENDIF.

    IF me->mo_dialogbox IS BOUND.

      me->mo_dialogbox->free(
        EXCEPTIONS
          cntl_error        = 0
          cntl_system_error = 0
          OTHERS            = 0
      ).

    ENDIF.

    CLEAR: me->mo_abapeditor,
           me->mo_textedit,
           me->mo_toolbar,
           me->mo_splitter,
           me->mo_dock,
           me->mo_dialogbox.

  ENDMETHOD.


  METHOD on_close.

    me->free( ).

  ENDMETHOD.


  METHOD on_function_selected.

    CASE fcode.

      WHEN 'SEND'.

        me->_handle_send_message( ).

      WHEN 'ACCEPT'.

        me->_insert_code_block( ).

      WHEN 'CLEAR'.

        me->_reset( ).

      WHEN 'CLOSE'.

        me->free( ).

      WHEN OTHERS.

        RETURN.

    ENDCASE.

  ENDMETHOD.


  METHOD run.

    me->_render( ).

  ENDMETHOD.


  METHOD set_abap_editor_integ_off.

    me->_abap_editor_integration = abap_false.

  ENDMETHOD.


  METHOD set_abap_editor_integ_on.

    me->_abap_editor_integration = abap_true.

  ENDMETHOD.


  METHOD set_api.

    me->_o_api = io_api.

  ENDMETHOD.


  METHOD set_popup_size.

    me->_popup_height = i_height.
    me->_popup_width = i_width.

  ENDMETHOD.


  METHOD set_prompt_template.

    me->_o_prompt_template = io_prompt_template.

  ENDMETHOD.


  METHOD _get_abap_editor_context.

    FIELD-SYMBOLS: <lo_editor> TYPE REF TO cl_wb_editor.

    DATA: lo_source TYPE REF TO cl_wb_source.

    DATA: lt_source TYPE rswsourcet.

    FREE r_context.

    r_context = 'No coding context available.'.

    ASSIGN ('(SAPLEDITOR_START)ABAP_EDITOR') TO <lo_editor>.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(l_cursor_position) = <lo_editor>->cursor-index.

    <lo_editor>->get_source_instance( IMPORTING source_object = lo_source ).

    IF lo_source IS NOT BOUND.
      RETURN.
    ENDIF.

    lo_source->get_source_tab( EXPORTING use_control = 'X' IMPORTING source = lt_source[] ).

    r_context = |```abap\n|.

    LOOP AT lt_source ASSIGNING FIELD-SYMBOL(<code_line>).

      IF sy-tabix = l_cursor_position.
        r_context = |{ r_context } \n@CURSOR_POSITION\n|.
      ENDIF.

      r_context = |{ r_context } { <code_line> } \n|.

    ENDLOOP.

    r_context = |{ r_context }\n```\n|.

  ENDMETHOD.


  METHOD _insert_code_block.

    FIELD-SYMBOLS: <lo_editor> TYPE REF TO cl_wb_editor.

    ASSIGN ('(SAPLEDITOR_START)ABAP_EDITOR') TO <lo_editor>.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    me->mo_abapeditor->get_text(
*      EXPORTING
*        name                   =                  " document name
      IMPORTING
        table                  = me->mt_buffer     " document text
*        is_modified            =                  " modify status of text
      EXCEPTIONS
        error_dp               = 1
        error_cntl_call_method = 2
        OTHERS                 = 3
    ).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(l_cursor_position) = <lo_editor>->cursor-index.

    <lo_editor>->insert_block(
      EXPORTING
        p_line       = l_cursor_position             " Position of Insert
*        p_add_method = space                        " Call by Add
      CHANGING
        p_buffer     = me->mt_buffer                 " Statement Block to be Inserted
    ).

  ENDMETHOD.

  METHOD _handle_send_message.

    DATA: l_url          TYPE c LENGTH 250,
          l_assigned     TYPE c LENGTH 250,
          l_user_message TYPE string,
          l_message      TYPE string,
          l_context      TYPE string,
          l_response     TYPE string.

    IF me->mo_abapeditor IS NOT BOUND.
      RETURN.
    ENDIF.

    me->mo_textedit->get_textstream( IMPORTING text = l_user_message ). " <-- l_user_message still empty

    cl_gui_cfw=>flush( ). " <-- now it's not empty anymore.

    IF l_user_message IS INITIAL.
      RETURN.
    ENDIF.

    l_message = l_user_message.

    IF me->_o_prompt_template IS BOUND.

      IF me->_abap_editor_integration = abap_true.

        l_context = me->_get_abap_editor_context( ).

      ENDIF.

      NEW ycl_aai_prompt( )->generate_prompt_from_template(
        EXPORTING
          i_o_template = me->_o_prompt_template
          i_s_params   = VALUE yif_aai_prompt=>ty_params_basic_s( user_message = l_user_message
                                                                  context = l_context )
        RECEIVING
          r_prompt     = l_message
      ).

    ENDIF.

    " Call LLM Chat API
    me->_o_api->chat(
      EXPORTING
        i_message    = l_message
        i_new        = abap_true
      IMPORTING
        e_response   = l_response
        e_t_response = DATA(lt_response)
    ).

    " Clear user's question
    me->mo_textedit->set_textstream(
      EXPORTING
        text                   = space                 " Text as String with Carriage Returns and Linefeeds
      EXCEPTIONS
        error_cntl_call_method = 1                " Error Calling COM Method
        not_supported_by_gui   = 2                " Method is not supported by installed GUI
        OTHERS                 = 3
    ).

    IF sy-subrc <> 0.
      " TODO: handle error!
    ENDIF.

    DATA(l_comment_line) = '"'.

    FREE me->mt_buffer.

    LOOP AT lt_response ASSIGNING FIELD-SYMBOL(<ls_response>).

      APPEND INITIAL LINE TO me->mt_buffer ASSIGNING FIELD-SYMBOL(<l_buffer>).

      FIND REGEX '```' IN <ls_response> IGNORING CASE.

      IF sy-subrc = 0.

        IF NOT <ls_response> CO '` '.

          l_comment_line = space.

          DATA(l_code_language) = <ls_response>.

          REPLACE REGEX '```' IN l_code_language WITH space.

          <ls_response> = |" >>> { condense( l_code_language ) } code example begin|.

        ELSE.

          l_comment_line = '"'.

          <ls_response> = |<<< { condense( l_code_language ) } code sample end|.

        ENDIF.

      ENDIF.

      <l_buffer> = <ls_response>.

      IF l_comment_line = '"'.
        <l_buffer> = |{ l_comment_line } { <l_buffer> }|.
      ENDIF.

    ENDLOOP.

    " Clear ABAP editor content
    me->mo_abapeditor->set_text(
      EXPORTING
        table           = me->mt_buffer
      EXCEPTIONS
        error_dp        = 1
        error_dp_create = 2
        error_code_page = 3
        OTHERS          = 4
    ).

    IF sy-subrc <> 0.
      " TODO: handle error!
    ENDIF.

    cl_gui_cfw=>flush( ).

  ENDMETHOD.


  METHOD _render.

    DATA: lt_events TYPE cntl_simple_events,
          ls_events TYPE LINE OF cntl_simple_events.

    DATA: l_url      TYPE c LENGTH 250,
          l_assigned TYPE c LENGTH 250.

    IF me->mo_dock IS BOUND OR me->mo_dialogbox IS BOUND.
      RETURN.
    ENDIF.

    IF me->_display_mode = mc_display_mode_dock.

      CREATE OBJECT me->mo_dock
        EXPORTING
          parent                      = cl_gui_container=>screen0                 " Parent container
          side                        = cl_gui_docking_container=>dock_at_right   " Side to Which Control is Docked
          ratio                       = 25                                        " Percentage of Screen: Takes Priority Over EXTENSION
        EXCEPTIONS
          cntl_error                  = 1
          cntl_system_error           = 2
          create_error                = 3
          lifetime_error              = 4
          lifetime_dynpro_dynpro_link = 5
          OTHERS                      = 6.

      IF sy-subrc <> 0.
        RETURN.
      ENDIF.

      CREATE OBJECT me->mo_splitter
        EXPORTING
          parent            = me->mo_dock
          rows              = 3
          columns           = 1
          left              = 5
        EXCEPTIONS
          cntl_error        = 1
          cntl_system_error = 2
          OTHERS            = 3.

      IF sy-subrc <> 0.
        RETURN.
      ENDIF.

    ENDIF.

    IF me->_display_mode = mc_display_mode_dialog.

      CREATE OBJECT me->mo_dialogbox
        EXPORTING
*         parent                      =                    " Parent container
          width                       = me->_popup_width   " Width of This Container
          height                      = me->_popup_height  " Height of This Container
*         style                       =                    " Windows Style Attributes Applied to this Container
*         repid                       =                    " Report to Which This Control is Linked
*         dynnr                       =                    " Screen to Which the Control is Linked
*         lifetime                    = lifetime_default   " Lifetime
          top                         = 10                 " Top Position of Dialog Box
          left                        = 200                " Left Position of Dialog Box
          caption                     = TEXT-003           " Dialog Box Caption
*         no_autodef_progid_dynnr     =                    " Don't Autodefined Progid and Dynnr?
*         metric                      = 0                  " Metric
*         name                        =                    " Name
        EXCEPTIONS
          cntl_error                  = 1
          cntl_system_error           = 2
          create_error                = 3
          lifetime_error              = 4
          lifetime_dynpro_dynpro_link = 5
          event_already_registered    = 6
          error_regist_event          = 7
          OTHERS                      = 8.

      IF sy-subrc <> 0.
        RETURN.
      ENDIF.

      SET HANDLER me->on_close FOR me->mo_dialogbox.

      CREATE OBJECT me->mo_splitter
        EXPORTING
          parent            = me->mo_dialogbox
          rows              = 3
          columns           = 1
          left              = 5
        EXCEPTIONS
          cntl_error        = 1
          cntl_system_error = 2
          OTHERS            = 3.

      IF sy-subrc <> 0.
        RETURN.
      ENDIF.

    ENDIF.

    IF me->_display_mode = mc_display_mode_custom AND me->mo_custom_container IS BOUND.

      CREATE OBJECT me->mo_splitter
        EXPORTING
          parent            = me->mo_custom_container
          rows              = 3
          columns           = 1
          left              = 5
        EXCEPTIONS
          cntl_error        = 1
          cntl_system_error = 2
          OTHERS            = 3.

      IF sy-subrc <> 0.
        RETURN.
      ENDIF.

    ENDIF.

    IF me->mo_splitter IS NOT BOUND.
      RETURN.
    ENDIF.

    DATA(lo_abapeditor_container) = me->mo_splitter->get_container( row = 1 column = 1 ).

    DATA(lo_textedit_container) = me->mo_splitter->get_container( row = 2 column = 1 ).

    DATA(lo_toolbar_container) = me->mo_splitter->get_container( row = 3 column = 1 ).

    " Set the textedit container size
    me->mo_splitter->set_row_height(
      EXPORTING
        id                = 2                 " Row ID
        height            = 15
      EXCEPTIONS
        cntl_error        = 0
        cntl_system_error = 0
        OTHERS            = 0
    ).

    " Set the toolbar container size
    me->mo_splitter->set_row_height(
      EXPORTING
        id                = 3                 " Row ID
        height            = 5
      EXCEPTIONS
        cntl_error        = 0
        cntl_system_error = 0
        OTHERS            = 0
    ).

    CREATE OBJECT me->mo_abapeditor
      EXPORTING
        parent           = lo_abapeditor_container
        max_number_chars = 255
*       source_type      = 'ABAP'
      .

    CREATE OBJECT me->mo_textedit
      EXPORTING
        parent                 = lo_textedit_container                " Parent Container
      EXCEPTIONS
        error_cntl_create      = 1
        error_cntl_init        = 2
        error_cntl_link        = 3
        error_dp_create        = 4
        gui_type_not_supported = 5
        OTHERS                 = 6.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    me->mo_textedit->set_statusbar_mode(
      EXPORTING
        statusbar_mode         = 0                                 " visibility of statusbar; eq 0: OFF ; ne 0: ON
      EXCEPTIONS
        error_cntl_call_method = 0
        invalid_parameter      = 0
        OTHERS                 = 0
    ).

    me->mo_textedit->set_toolbar_mode(
      EXPORTING
        toolbar_mode           = 0            " visibility of toolbar; eq 0: OFF ; ne 0: ON
      EXCEPTIONS
        error_cntl_call_method = 0
        invalid_parameter      = 0
        OTHERS                 = 0
    ).

    CREATE OBJECT me->mo_toolbar
      EXPORTING
        parent             = lo_toolbar_container                  " Container name
        align_right        = cl_gui_toolbar=>align_at_right
      EXCEPTIONS
        cntl_install_error = 1
        cntl_error         = 2
        cntb_wrong_version = 3
        OTHERS             = 4.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    me->mo_toolbar->add_button(
      EXPORTING
        fcode            = 'SEND'                    " Function Code Associated with Button
        icon             = icon_trend_up             " Icon Name Defined Like "@0a@"
        butn_type        = 0                         " Button Types Defined in CNTB
        text             = TEXT-001                  " Text Shown to the Right of the Image
      EXCEPTIONS
        cntl_error       = 1
        cntb_btype_error = 2
        cntb_error_fcode = 3
        OTHERS           = 4
    ).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF me->_abap_editor_integration = abap_true.

      me->mo_toolbar->add_button(
        EXPORTING
          fcode            = 'ACCEPT'                  " Function Code Associated with Button
          icon             = icon_import               " Icon Name Defined Like "@0a@"
          butn_type        = 0                         " Button Types Defined in CNTB
          text             = 'Accept'                  " Text Shown to the Right of the Image
        EXCEPTIONS
          cntl_error       = 0
          cntb_btype_error = 0
          cntb_error_fcode = 0
          OTHERS           = 0
      ).

    ENDIF.

    me->mo_toolbar->add_button(
        EXPORTING
          fcode            = 'CLEAR'                   " Function Code Associated with Button
          icon             = icon_delete               " Icon Name Defined Like "@0a@"
          butn_type        = 0                         " Button Types Defined in CNTB
          text             = 'Clear'                   " Text Shown to the Right of the Image
        EXCEPTIONS
          cntl_error       = 0
          cntb_btype_error = 0
          cntb_error_fcode = 0
          OTHERS           = 0
      ).

    IF me->_display_mode <> mc_display_mode_custom.

      me->mo_toolbar->add_button(
        EXPORTING
          fcode            = 'CLOSE'                   " Function Code Associated with Button
          icon             = icon_close                " Icon Name Defined Like "@0a@"
          butn_type        = 0                         " Button Types Defined in CNTB
          text             = TEXT-002                  " Text Shown to the Right of the Image
        EXCEPTIONS
          cntl_error       = 0
          cntb_btype_error = 0
          cntb_error_fcode = 0
          OTHERS           = 0
      ).

    ENDIF.

    SET HANDLER me->on_function_selected FOR me->mo_toolbar.

*   Registering toolbar events
    CLEAR: ls_events,
           lt_events[].

    ls_events-eventid = cl_gui_toolbar=>m_id_function_selected.
    ls_events-appl_event = ' '.
    APPEND ls_events TO lt_events.

    CALL METHOD me->mo_toolbar->set_registered_events
      EXPORTING
        events = lt_events.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    me->mo_textedit->set_textstream( space ).

    me->mo_textedit->set_focus(
      EXPORTING
        control           = mo_textedit
      EXCEPTIONS
        cntl_error        = 0
        cntl_system_error = 0
        OTHERS            = 0
    ).

    cl_gui_cfw=>flush( ).

  ENDMETHOD.


  METHOD _reset.

    FREE me->mt_buffer.

    me->mo_textedit->set_textstream( space ).

    me->mo_abapeditor->set_text(
      EXPORTING
        table           = me->mt_buffer
      EXCEPTIONS
        error_dp        = 0
        error_dp_create = 0
        error_code_page = 0
        OTHERS          = 0
    ).

  ENDMETHOD.

ENDCLASS.
