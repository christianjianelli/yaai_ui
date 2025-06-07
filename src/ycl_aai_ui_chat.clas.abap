CLASS ycl_aai_ui_chat DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES ty_html TYPE c LENGTH 1000.

    TYPES ty_html_t TYPE STANDARD TABLE OF ty_html WITH DEFAULT KEY.

    DATA: mo_dock        TYPE REF TO cl_gui_docking_container,
          mo_splitter    TYPE REF TO cl_gui_splitter_container,
          mo_html_viewer TYPE REF TO cl_gui_html_viewer,
          mo_textedit    TYPE REF TO cl_gui_textedit,
          mo_toolbar     TYPE REF TO cl_gui_toolbar.

    DATA: mt_html TYPE STANDARD TABLE OF ty_html WITH DEFAULT KEY READ-ONLY.

    DATA: m_url TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        i_t_html TYPE ty_html_t OPTIONAL.

    METHODS run.

    METHODS on_function_selected FOR EVENT function_selected OF cl_gui_toolbar
      IMPORTING fcode.

    METHODS set_ollama
      IMPORTING
        io_ollama TYPE REF TO yif_aai_ollama.

  PROTECTED SECTION.

  PRIVATE SECTION.

    DATA: _ollama TYPE REF TO yif_aai_ollama.

    METHODS _render.

ENDCLASS.



CLASS ycl_aai_ui_chat IMPLEMENTATION.

  METHOD constructor.

    IF i_t_html IS SUPPLIED.
      me->mt_html = i_t_html.
      RETURN.
    ENDIF.

    APPEND '<html><body>' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND '<div id="content"></div>' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND '<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND '<script>' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND 'var markdown = "## ABAP AI Chat\n\nRendered by **marked**.";' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND 'document.getElementById("content").innerHTML = marked.parse(markdown);' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND '</script>' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND '</body></html>' && cl_abap_char_utilities=>newline TO me->mt_html.

  ENDMETHOD.

  METHOD run.

    me->_render( ).

  ENDMETHOD.

  METHOD _render.

    DATA: lt_events TYPE cntl_simple_events,
          ls_events TYPE LINE OF cntl_simple_events.

    DATA: l_url      TYPE c LENGTH 250,
          l_assigned TYPE c LENGTH 250.

    IF me->mo_dock IS BOUND.
      RETURN.
    ENDIF.

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
      EXCEPTIONS
        cntl_error        = 1
        cntl_system_error = 2
        OTHERS            = 3.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lo_html_viewer_container) = me->mo_splitter->get_container( row = 1 column = 1 ).

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
        height            = 15
      EXCEPTIONS
        cntl_error        = 0
        cntl_system_error = 0
        OTHERS            = 0
    ).

    CREATE OBJECT me->mo_html_viewer
      EXPORTING
        parent             = lo_html_viewer_container                 " Container
      EXCEPTIONS
        cntl_error         = 1
        cntl_install_error = 2
        dp_install_error   = 3
        dp_error           = 4
        OTHERS             = 5.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

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

    CREATE OBJECT me->mo_toolbar
      EXPORTING
        parent             = lo_toolbar_container                  " Container name
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
        fcode            = 'ASK'                     " Function Code Associated with Button
        icon             = icon_helpassistent_on     " Icon Name Defined Like "@0a@"
*       is_disabled      =                           " Button Status
        butn_type        = 0                         " Button Types Defined in CNTB
        text             = 'Ask'                     " Text Shown to the Right of the Image
*       quickinfo        =                           " Purpose of Button Text
      EXCEPTIONS
        cntl_error       = 1                " Error in CFW Call
        cntb_btype_error = 2                " Bottle Button Type
        cntb_error_fcode = 3                " F Code is not Unique
        OTHERS           = 4
    ).

    IF sy-subrc <> 0.
      RETURN.
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

    mo_html_viewer->load_data(
        EXPORTING
          url                    = l_url                " URL
        IMPORTING
          assigned_url           = l_assigned           " URL
        CHANGING
          data_table             = me->mt_html              " data table
        EXCEPTIONS
          dp_invalid_parameter   = 1
          dp_error_general       = 2
          cntl_error             = 3
          html_syntax_notcorrect = 4
          OTHERS                 = 5
      ).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    me->m_url = l_assigned.

    mo_html_viewer->show_url( l_assigned ).

  ENDMETHOD.

  METHOD on_function_selected.

    DATA: l_url           TYPE c LENGTH 250,
          l_assigned      TYPE c LENGTH 250,
          l_user_question TYPE string,
          l_response      TYPE string.

    me->mo_textedit->get_textstream( IMPORTING text = l_user_question ). ""// <-- user_question still empty

    cl_gui_cfw=>flush( ). ""//<-- now it's not empty anymore.

    IF l_user_question IS INITIAL.
      RETURN.
    ENDIF.

    me->_ollama->chat(
      EXPORTING
        i_message    = l_user_question
      IMPORTING
        e_t_response = DATA(lt_response)
    ).

    FREE me->mt_html.

    APPEND '<html><body>' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND '<div id="content"></div>' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND '<div id="footer"></div>' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND '<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND '<script>' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND 'var markdown = "";' && cl_abap_char_utilities=>newline TO me->mt_html.
    LOOP AT lt_response ASSIGNING FIELD-SYMBOL(<l_response>).
      APPEND 'markdown = markdown + "\n" + ' && /ui2/cl_json=>serialize( <l_response> ) && ';' && cl_abap_char_utilities=>newline TO me->mt_html.
    ENDLOOP.
    APPEND 'document.getElementById("content").innerHTML = marked.parse(markdown);' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND 'const myElement = document.getElementById("footer");' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND 'myElement.scrollIntoView({behavior: "smooth"});' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND '</script>' && cl_abap_char_utilities=>newline TO me->mt_html.
    APPEND '</body></html>' && cl_abap_char_utilities=>newline TO me->mt_html.

    l_url = me->m_url.

    mo_html_viewer->load_data(
      EXPORTING
        url          = l_url
      IMPORTING
        assigned_url = l_assigned
      CHANGING
        data_table   = me->mt_html
    ).

    mo_html_viewer->show_url( l_assigned ).

  ENDMETHOD.

  METHOD set_ollama.

    me->_ollama = io_ollama.

  ENDMETHOD.

ENDCLASS.
