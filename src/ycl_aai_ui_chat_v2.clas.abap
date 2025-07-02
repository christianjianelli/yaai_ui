CLASS ycl_aai_ui_chat_v2 DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES ty_html TYPE c LENGTH 2000.

    TYPES ty_html_t TYPE STANDARD TABLE OF ty_html WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_chat_message_s,
             role     TYPE string,
             content  TYPE string,
             datetime TYPE string,
           END OF ty_chat_message_s.

    TYPES ty_messages_t TYPE STANDARD TABLE OF ty_chat_message_s WITH DEFAULT KEY.

    CONSTANTS: mc_display_mode_dock   TYPE c LENGTH 10 VALUE 'DOCK',
               mc_display_mode_dialog TYPE c LENGTH 10 VALUE 'DIALOG',
               mc_display_mode_custom TYPE c LENGTH 10 VALUE 'CUSTOM'.

    DATA: mo_dock               TYPE REF TO cl_gui_docking_container,
          mo_dialogbox          TYPE REF TO cl_gui_dialogbox_container,
          mo_splitter           TYPE REF TO cl_gui_splitter_container,
          mo_html_viewer        TYPE REF TO cl_gui_html_viewer,
          mo_html_viewer_prompt TYPE REF TO cl_gui_html_viewer,
          mo_custom_container   TYPE REF TO cl_gui_custom_container.

    DATA: mt_html        TYPE STANDARD TABLE OF ty_html WITH DEFAULT KEY READ-ONLY,
          mt_html_prompt TYPE STANDARD TABLE OF ty_html WITH DEFAULT KEY READ-ONLY.

    DATA: m_url                  TYPE string READ-ONLY,
          m_submit_button_text   TYPE string VALUE 'Send',
          m_new_chat_button_text TYPE string VALUE 'New chat'.

    METHODS constructor
      IMPORTING
        i_greeting          TYPE csequence OPTIONAL
        i_display_mode      TYPE csequence DEFAULT mc_display_mode_dock
        io_api              TYPE REF TO yif_aai_chat OPTIONAL
        io_custom_container TYPE REF TO cl_gui_custom_container OPTIONAL.

    METHODS run.

    METHODS handle_sapevent FOR EVENT sapevent OF cl_gui_html_viewer
      IMPORTING action
                frame
                getdata
                postdata
                query_table.

    METHODS on_close FOR EVENT close OF cl_gui_dialogbox_container.

    METHODS set_api
      IMPORTING
        io_api TYPE REF TO yif_aai_chat.

    METHODS set_rag
      IMPORTING
        io_rag TYPE REF TO yif_aai_rag.

    METHODS set_popup_size
      IMPORTING
        i_height TYPE i
        i_width  TYPE i.

    METHODS set_logo
      IMPORTING
        i_logo TYPE csequence.

    METHODS hide_logo.

    METHODS set_max_length
      IMPORTING
        i_max_length TYPE i.

    METHODS free.

  PROTECTED SECTION.

  PRIVATE SECTION.

    DATA: _o_api TYPE REF TO yif_aai_chat,
          _o_rag TYPE REF TO yif_aai_rag.

    DATA: _chat_messages_t TYPE ty_messages_t.

    DATA: _greeting     TYPE string,
          _display_mode TYPE c LENGTH 10 VALUE mc_display_mode_dock,
          _popup_height TYPE i VALUE 400,
          _popup_width  TYPE i VALUE 400,
          _logo         TYPE string VALUE 'https://christianjianelli.github.io/abapAI.svg',
          _no_logo      TYPE string,
          _new          TYPE abap_bool,
          _max_length   TYPE i VALUE 500.

    METHODS _render.

    METHODS _get_html
      IMPORTING
                i_add_typing_animation TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rt_html)         TYPE ty_html_t.

    METHODS _get_html_prompt
      RETURNING VALUE(rt_html) TYPE ty_html_t.

    METHODS _get_css
      RETURNING VALUE(rt_css) TYPE ty_html_t.

    METHODS _get_css_prompt
      RETURNING VALUE(rt_css) TYPE ty_html_t.

    METHODS _get_chat_messages
      IMPORTING
                i_add_typing_animation TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rt_html)         TYPE ty_html_t.

    METHODS _handle_send_message
      IMPORTING
        i_message TYPE csequence.

    METHODS _start_new_chat.

ENDCLASS.



CLASS ycl_aai_ui_chat_v2 IMPLEMENTATION.

  METHOD constructor.

    me->_new = abap_true.

    IF i_greeting IS SUPPLIED AND i_greeting IS NOT INITIAL.

      me->_greeting = i_greeting.

      APPEND VALUE #( role = 'assistant'
                      content = i_greeting
                      datetime = |{ sy-datlo+6(2) }.{ sy-datlo+4(2) }.{ sy-datlo(4) } { sy-timlo(2) }:{ sy-datlo+2(2) }| ) TO me->_chat_messages_t.

    ENDIF.

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

  ENDMETHOD.

  METHOD run.

    me->_render( ).

  ENDMETHOD.

  METHOD _render.

    DATA: lt_events TYPE cntl_simple_events,
          ls_events TYPE LINE OF cntl_simple_events.

    DATA: l_url      TYPE c LENGTH 250,
          l_assigned TYPE c LENGTH 250.

    IF me->mo_splitter IS BOUND.
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
          rows              = 2
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
          rows              = 2
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
          rows              = 2
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

    DATA(lo_html_viewer_container) = me->mo_splitter->get_container( row = 1 column = 1 ).

    DATA(lo_html_viewer_prompt_cont) = me->mo_splitter->get_container( row = 2 column = 1 ).

    " Set the html prompt container height
    me->mo_splitter->set_row_height(
      EXPORTING
        id                = 2                 " Row ID
        height            = 25
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

    CREATE OBJECT me->mo_html_viewer_prompt
      EXPORTING
        parent             = lo_html_viewer_prompt_cont                 " Container
      EXCEPTIONS
        cntl_error         = 1
        cntl_install_error = 2
        dp_install_error   = 3
        dp_error           = 4
        OTHERS             = 5.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SET HANDLER me->handle_sapevent FOR me->mo_html_viewer_prompt.

    ls_events-eventid = 1.
    ls_events-appl_event = 'X'.

    APPEND ls_events TO lt_events.

    CALL METHOD me->mo_html_viewer_prompt->set_registered_events EXPORTING events = lt_events.

    me->mt_html = me->_get_html( ).

    me->mo_html_viewer->load_data(
        EXPORTING
          url                    = l_url
        IMPORTING
          assigned_url           = l_assigned
        CHANGING
          data_table             = me->mt_html
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

    me->mo_html_viewer->show_url( l_assigned ).

    me->mt_html_prompt = me->_get_html_prompt( ).

    CLEAR: l_url,
           l_assigned.

    me->mo_html_viewer_prompt->load_data(
        EXPORTING
          url                    = l_url
        IMPORTING
          assigned_url           = l_assigned
        CHANGING
          data_table             = me->mt_html_prompt
        EXCEPTIONS
          dp_invalid_parameter   = 1
          dp_error_general       = 2
          cntl_error             = 3
          html_syntax_notcorrect = 4
          OTHERS                 = 5
      ).

    me->mo_html_viewer_prompt->show_url( l_assigned ).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    cl_gui_cfw=>flush( ).

  ENDMETHOD.

  METHOD handle_sapevent.

    DATA ls_text TYPE string.

    READ TABLE query_table TRANSPORTING NO FIELDS
      WITH KEY name = 'NEW_CHAT'.

    IF sy-subrc = 0.

      me->_start_new_chat( ).

      RETURN.

    ENDIF.

    LOOP AT query_table ASSIGNING FIELD-SYMBOL(<query_table>).
      ls_text = ls_text && <query_table>-value.
    ENDLOOP.

    ls_text = cl_http_utility=>decode_base64( encoded = ls_text ).
    ls_text = cl_http_utility=>unescape_url( escaped = ls_text ).

    IF ls_text IS INITIAL.

      RETURN.

    ENDIF.

    me->_handle_send_message( ls_text ).

  ENDMETHOD.

  METHOD set_api.

    me->_o_api = io_api.

  ENDMETHOD.

  METHOD set_rag.

    me->_o_rag = io_rag.

  ENDMETHOD.

  METHOD _get_css.

    FREE rt_css.

    APPEND '<style>' TO rt_css.
    APPEND '/* General Body and Font Styles */' TO rt_css.
    APPEND '    body {' TO rt_css.
    APPEND '        font-family: ''Segoe UI'', Tahoma, Geneva, Verdana, sans-serif;' TO rt_css.
    APPEND '        /* A system font that looks native on Windows */' TO rt_css.
    APPEND '        margin: 0;' TO rt_css.
    APPEND '        padding: 10px;' TO rt_css.
    APPEND '        /* Overall padding around the message area */' TO rt_css.
    APPEND '        background-color: #f0f2f5;' TO rt_css.
    APPEND '        /* Very light grey background for a clean base */' TO rt_css.
    APPEND '        color: #333;' TO rt_css.
    APPEND '        /* Dark grey for general text for good contrast */' TO rt_css.
    APPEND '        line-height: 1.45;' TO rt_css.
    APPEND '        /* Enhances readability by adding space between lines */' TO rt_css.
    APPEND '        font-size: 0.9em;' TO rt_css.
    APPEND '        /* Slightly reduced base font size to fit more content in the narrow window */' TO rt_css.
    APPEND '        box-sizing: border-box;' TO rt_css.
    APPEND '        /* Crucial: Includes padding and border in element''s total width/height */' TO rt_css.
    APPEND '        overflow-y: auto;' TO rt_css.
    APPEND '        /* Enable vertical scrolling if content overflows */' TO rt_css.
    APPEND '        height: 100vh;' TO rt_css.
    APPEND '        /* Ensure the body takes full viewport height for proper scrolling */' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    /* Message Container: Flexbox for vertical stacking */' TO rt_css.
    APPEND '    .message-container {' TO rt_css.
    APPEND '        display: flex;' TO rt_css.
    APPEND '        flex-direction: column;' TO rt_css.
    APPEND '        gap: 15px;' TO rt_css.
    APPEND '        /* Spacing between individual messages */' TO rt_css.
    APPEND '        max-width: 100%;' TO rt_css.
    APPEND '        /* Ensures the container doesn''t overflow its parent */' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    /* Individual Message Styles */' TO rt_css.
    APPEND '    .message {' TO rt_css.
    APPEND '        display: flex;' TO rt_css.
    APPEND '        flex-direction: column;' TO rt_css.
    APPEND '        max-width: 100%;' TO rt_css.
    APPEND '        /* Each message takes full available width */' TO rt_css.
    APPEND '        /* Default alignment for LLM messages (align-items: flex-start) */' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    /* Message Bubble Styling */' TO rt_css.
    APPEND '    .message-bubble {' TO rt_css.
    APPEND '        padding: 10px 14px;' TO rt_css.
    APPEND '        border-radius: 18px;' TO rt_css.
    APPEND '        /* Smoothly rounded corners for a modern chat look */' TO rt_css.
    APPEND '        max-width: calc(100% - 40px);' TO rt_css.
    APPEND '        /* Limits bubble width, leaving space on the opposite side */' TO rt_css.
    APPEND '        word-wrap: break-word;' TO rt_css.
    APPEND '        /* Prevents long words/URLs from overflowing */' TO rt_css.
    APPEND '        box-shadow: 0 1px 2px rgba(0, 0, 0, 0.08);' TO rt_css.
    APPEND '        /* Subtle shadow for depth */' TO rt_css.
    APPEND '        position: relative;' TO rt_css.
    APPEND '        /* Needed for any future additions like small "tail" elements */' TO rt_css.
    APPEND '        min-width: 300px;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    .message-bubble p {' TO rt_css.
    APPEND '        margin: 0;' TO rt_css.
    APPEND '        /* Remove default paragraph margins inside the bubble */' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    /* LLM (AI Assistant) Message Specific Styles */' TO rt_css.
    APPEND '    .llm-message {' TO rt_css.
    APPEND '        align-items: flex-start;' TO rt_css.
    APPEND '        /* Aligns LLM messages to the left */' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    .llm-message .message-bubble {' TO rt_css.
    APPEND '        background-color: #ffffff;' TO rt_css.
    APPEND '        /* Very light blue for LLM messages */' TO rt_css.
    APPEND '        color: #2c3e50;' TO rt_css.
    APPEND '        /* Darker blue-grey for LLM text */' TO rt_css.
    APPEND '        border-bottom-left-radius: 4px;' TO rt_css.
    APPEND '        /* Slightly less rounded corner for a distinct visual cue */' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    /* User Message Specific Styles */' TO rt_css.
    APPEND '    .user-message {' TO rt_css.
    APPEND '        align-self: flex-end;' TO rt_css.
    APPEND '        /* Pushes the entire message block to the right */' TO rt_css.
    APPEND '        align-items: flex-end;' TO rt_css.
    APPEND '        /* Aligns content (bubble, timestamp) within the block to the right */' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    .user-message .message-bubble {' TO rt_css.
    APPEND '        background-color: #e9eef6;' TO rt_css.
    APPEND '        /* Soft green for user messages */' TO rt_css.
    APPEND '        color: #2c3e50;' TO rt_css.
    APPEND '        /* Same dark blue-grey for user text */' TO rt_css.
    APPEND '        border-bottom-right-radius: 4px;' TO rt_css.
    APPEND '        /* Slightly less rounded corner for a distinct visual cue */' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    /* Message Timestamp */' TO rt_css.
    APPEND '    .message-timestamp {' TO rt_css.
    APPEND '        font-size: 0.7em;' TO rt_css.
    APPEND '        /* Smaller font size for the timestamp */' TO rt_css.
    APPEND '        color: #888;' TO rt_css.
    APPEND '        /* Muted grey for timestamps */' TO rt_css.
    APPEND '        margin-top: 4px;' TO rt_css.
    APPEND '        /* Space between bubble and timestamp */' TO rt_css.
    APPEND '        padding: 0 8px;' TO rt_css.
    APPEND '        /* Horizontal padding to align with bubble content */' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    .user-message .message-timestamp {' TO rt_css.
    APPEND '        text-align: right;' TO rt_css.
    APPEND '        /* Aligns user timestamps to the right */' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    .llm-message .message-timestamp {' TO rt_css.
    APPEND '        text-align: left;' TO rt_css.
    APPEND '        /* Aligns LLM timestamps to the left */' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    /* User Typing Animation */' TO rt_css.
    APPEND '    .user-typing {' TO rt_css.
    APPEND '        display: flex;' TO rt_css.
    APPEND '        align-items: center;' TO rt_css.
    APPEND '        height: 24px;' TO rt_css.
    APPEND '        margin-right: 8px;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    .user-typing-dot {' TO rt_css.
    APPEND '        width: 7px;' TO rt_css.
    APPEND '        height: 7px;' TO rt_css.
    APPEND '        margin: 0 2px;' TO rt_css.
    APPEND '        border-radius: 50%;' TO rt_css.
    APPEND '        background: #a0a0a0;' TO rt_css.
    APPEND '        opacity: 0.5;' TO rt_css.
    APPEND '        animation: userTypingBlink 1.2s infinite both;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    .user-typing-dot:nth-child(2) {' TO rt_css.
    APPEND '        animation-delay: 0.2s;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    .user-typing-dot:nth-child(3) {' TO rt_css.
    APPEND '        animation-delay: 0.4s;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    @keyframes userTypingBlink {' TO rt_css.
    APPEND '        0%, 80%, 100% { opacity: 0.5; }' TO rt_css.
    APPEND '        40% { opacity: 1; }' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    pre {' TO rt_css.
    APPEND '        background: #fff;' TO rt_css.
    APPEND '        border-left: 3px solid #c9d5e9;' TO rt_css.
    APPEND '        border-radius: 0 4px 4px 0;' TO rt_css.
    APPEND '        padding: 16px;' TO rt_css.
    APPEND '        color: #333;' TO rt_css.
    APPEND '        font-family: ''Courier New'', Courier, monospace;' TO rt_css.
    APPEND '        font-size: 12px;' TO rt_css.
    APPEND '        line-height: 1.4;' TO rt_css.
    APPEND '        overflow-x: auto;' TO rt_css.
    APPEND '        margin: 1em 0;' TO rt_css.
    APPEND '        box-shadow: 0 1px 3px rgba(0,0,0,0.12);' TO rt_css.
    APPEND '        scrollbar-width: thin;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    /* For WebKit browsers (Chrome, Safari) */' TO rt_css.
    APPEND '    pre::-webkit-scrollbar {' TO rt_css.
    APPEND '        height: 5px;' TO rt_css.
    APPEND '        width: 5px;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '</style>' TO rt_css.

  ENDMETHOD.

  METHOD _get_css_prompt.

    APPEND '<style>' TO rt_css.

    APPEND '    html, body {' TO rt_css.
    APPEND '        height: 100%;' TO rt_css.
    APPEND '        margin: 0;' TO rt_css.
    APPEND '        padding: 0;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    body {' TO rt_css.
    APPEND '        background: #f6f8fa;' TO rt_css.
    APPEND '        font-family: "Segoe UI", Arial, sans-serif;' TO rt_css.
    APPEND '        display: flex;' TO rt_css.
    APPEND '        align-items: flex-start;' TO rt_css.
    APPEND '        justify-content: center;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    form {' TO rt_css.
    APPEND '        background: #fff;' TO rt_css.
    APPEND '        margin: 6px;' TO rt_css.
    APPEND '        padding: 12px;' TO rt_css.
    APPEND '        border-radius: 10px;' TO rt_css.
    APPEND '        box-shadow: 0 2px 12px rgba(0,0,0,0.07);' TO rt_css.
    APPEND '        width: 98vw;' TO rt_css.
    APPEND '        max-width: 420px;' TO rt_css.
    APPEND '        min-width: 0;' TO rt_css.
    APPEND '        display: flex;' TO rt_css.
    APPEND '        flex-direction: column;' TO rt_css.
    APPEND '        align-items: stretch;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    textarea {' TO rt_css.
    APPEND '        width: 100%;' TO rt_css.
    APPEND '        min-height: 50px;' TO rt_css.
    APPEND '        padding: 5px;' TO rt_css.
    APPEND '        border: 1px solid #d1d5db;' TO rt_css.
    APPEND '        border-radius: 5px;' TO rt_css.
    APPEND '        font-size: 0.85rem;' TO rt_css.
    APPEND '        font-family: inherit;' TO rt_css.
    APPEND '        background: #f9fafb;' TO rt_css.
    APPEND '        resize: vertical;' TO rt_css.
    APPEND '        transition: border-color 0.2s, box-shadow 0.2s;' TO rt_css.
    APPEND '        box-shadow: 0 1px 2px rgba(0,0,0,0.03);' TO rt_css.
    APPEND '        outline: none;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    textarea:focus {' TO rt_css.
    APPEND '        border-color: #2563eb;' TO rt_css.
    APPEND '        background: #fff;' TO rt_css.
    APPEND '        box-shadow: 0 0 0 2px #2563eb33;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    button[type="submit"] {' TO rt_css.
    APPEND '        margin-top: 8px;' TO rt_css.
    APPEND '        padding: 5px 16px;' TO rt_css.
    APPEND '        border: none;' TO rt_css.
    APPEND '        border-radius: 5px;' TO rt_css.
    APPEND '        background: #2563eb;' TO rt_css.
    APPEND '        color: #fff;' TO rt_css.
    APPEND '        font-size: 0.75rem;' TO rt_css.
    APPEND '        font-weight: 500;' TO rt_css.
    APPEND '        cursor: pointer;' TO rt_css.
    APPEND '        transition: background 0.18s;' TO rt_css.
    APPEND '        box-shadow: 0 1px 4px rgba(37,99,235,0.07);' TO rt_css.
    APPEND '        align-self: flex-start;' TO rt_css.
    APPEND '        width: auto;' TO rt_css.
    APPEND '        min-width: 0;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    button[type="submit"]:hover {' TO rt_css.
    APPEND '        background: #1d4ed8;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    .new-chat-btn {' TO rt_css.
    APPEND '        margin-left: 5px;' TO rt_css.
    APPEND '        margin-top: 8px;' TO rt_css.
    APPEND '        padding: 5px 16px;' TO rt_css.
    APPEND '        border: none;' TO rt_css.
    APPEND '        border-radius: 5px;' TO rt_css.
    APPEND '        background: #e5e7eb;' TO rt_css.
    APPEND '        color: #374151;' TO rt_css.
    APPEND '        font-size: 0.75rem;' TO rt_css.
    APPEND '        font-weight: 500;' TO rt_css.
    APPEND '        cursor: pointer;' TO rt_css.
    APPEND '        transition: background 0.18s;' TO rt_css.
    APPEND '        box-shadow: 0 1px 4px rgba(0,0,0,0.04);' TO rt_css.
    APPEND '        align-self: flex-start;' TO rt_css.
    APPEND '        width: auto;' TO rt_css.
    APPEND '        min-width: 0;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '    .new-chat-btn:hover {' TO rt_css.
    APPEND '        background: #d1d5db;' TO rt_css.
    APPEND '    }' TO rt_css.

    APPEND '</style>' TO rt_css.

  ENDMETHOD.

  METHOD _get_html.

    FREE rt_html.

    APPEND '<!DOCTYPE html>' TO rt_html.
    APPEND '<html lang="en">' TO rt_html.

    APPEND '<head>' TO rt_html.
    APPEND '<meta charset="UTF-8">' TO rt_html.
    APPEND '<meta name="viewport" content="width=device-width, initial-scale=1.0">' TO rt_html.
    APPEND '<title>ABAP AI Chat</title>' TO rt_html.

    " CSS
    APPEND LINES OF me->_get_css( ) TO rt_html.

    APPEND '</head>' TO rt_html.
    APPEND '<body>' TO rt_html.
    APPEND '<div style="text-align: center;">' TO rt_html.
    APPEND '<img src="' && me->_logo && '" alt="Logo" style="height:35px; margin-bottom:10px;' && me->_no_logo && '">' TO rt_html.
    APPEND '</div>' TO rt_html.
    APPEND '<div class="message-container">' TO rt_html.

    " Chat Messages
    APPEND LINES OF me->_get_chat_messages( i_add_typing_animation ) TO rt_html.

    APPEND '</div>' TO rt_html.

    APPEND '<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>' TO rt_html.

    APPEND '<script>' TO rt_html.

    APPEND 'document.querySelectorAll(''.message.user-message .message-bubble p'').forEach(p => {' TO rt_html.
    APPEND '  p.innerHTML = marked.parse(p.textContent);' TO rt_html.
    APPEND '});' TO rt_html.

    APPEND 'document.querySelectorAll(''.message.llm-message .message-bubble .markdown-content'').forEach(el => {' TO rt_html.
    APPEND '  el.innerHTML = marked.parse(el.textContent);' TO rt_html.
    APPEND '});' TO rt_html.

    APPEND 'const userMessages = document.querySelectorAll(''.user-message'');' TO rt_html.
    APPEND 'if (userMessages.length > 0) {' TO rt_html.
    APPEND '  setTimeout(() => {userMessages[userMessages.length - 1].scrollIntoView({ behavior: ''smooth'', block: ''start'' })}, 500);' TO rt_html.
    APPEND '}' TO rt_html.

    APPEND 'const llmMessages = document.querySelectorAll(''.llm-message'');' TO rt_html.
    APPEND 'if (llmMessages.length > 0) {' TO rt_html.
    APPEND '  setTimeout(() => {llmMessages[llmMessages.length - 1].scrollIntoView({ behavior: ''smooth'', block: ''start'' })}, 1000);' TO rt_html.
    APPEND '}' TO rt_html.

    APPEND '</script>' TO rt_html.
    APPEND '</body>' TO rt_html.
    APPEND '</html>' TO rt_html.

  ENDMETHOD.

  METHOD _get_chat_messages.

    FREE rt_html.

    LOOP AT _chat_messages_t ASSIGNING FIELD-SYMBOL(<ls_message>).

      IF to_lower( <ls_message>-role ) = 'user'.

        APPEND '<div class="message user-message">' TO rt_html.
        APPEND '<div class="message-bubble">' TO rt_html.
        APPEND '<p>' && <ls_message>-content && '</p>' TO rt_html.
        APPEND '</div>' TO rt_html.
        APPEND '<div class="message-timestamp">' && <ls_message>-datetime && '</div>' TO rt_html.
        APPEND '</div>' TO rt_html.

      ENDIF.

      IF to_lower( <ls_message>-role ) = 'assistant'.

        APPEND '<div class="message llm-message">' TO rt_html.
        APPEND '<div class="message-bubble">' TO rt_html.
        APPEND '<div class="markdown-content">' TO rt_html.

        SPLIT <ls_message>-content AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_content).

        LOOP AT lt_content ASSIGNING FIELD-SYMBOL(<l_line_content>).
          APPEND INITIAL LINE TO rt_html ASSIGNING FIELD-SYMBOL(<l_line>).
          <l_line> = cl_abap_char_utilities=>newline && <l_line_content>.
        ENDLOOP.

        APPEND '</div>' TO rt_html.
        APPEND '</div>' TO rt_html.
        APPEND '<div class="message-timestamp">' && <ls_message>-datetime && '</div>' TO rt_html.
        APPEND '</div>' TO rt_html.

      ENDIF.

    ENDLOOP.

    IF i_add_typing_animation = abap_true.

      APPEND '<div class="message llm-message">' TO rt_html.
      APPEND '<div class="message-bubble">' TO rt_html.
      APPEND '<div class="user-typing">' TO rt_html.
      APPEND '<div class="user-typing-dot"></div>' TO rt_html.
      APPEND '<div class="user-typing-dot"></div>' TO rt_html.
      APPEND '<div class="user-typing-dot"></div>' TO rt_html.
      APPEND '</div>' TO rt_html.
      APPEND '</div>' TO rt_html.
      APPEND '<div class="message-timestamp"></div>' TO rt_html.
      APPEND '</div>' TO rt_html.

    ENDIF.

  ENDMETHOD.

  METHOD _get_html_prompt.

    FREE rt_html.

    APPEND '<html lang="en">' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '<head>' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '    <meta charset="UTF-8">' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '    <title>Split Textarea Form</title>' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND LINES OF me->_get_css_prompt( ) TO rt_html.

    APPEND '</head>' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '<body>' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '    <form id="chatForm" method="post" action="SAPEVENT:chat">' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '        <textarea id="mainText" name="mainText" maxlength="' && me->_max_length && '" placeholder="Enter your message here..."></textarea>' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '        <div style="display: flex; flex-direction: row;">' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            <button type="submit">' && me->m_submit_button_text && '</button>' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            <button type="button" class="new-chat-btn" id="newChatBtn">' && me->m_new_chat_button_text && '</button>' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '        </div>' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '    </form>' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '    <script>' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '        document.getElementById("chatForm").addEventListener("submit", function(e) {' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            e.preventDefault();' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            // Remove old hidden inputs' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            Array.from(this.querySelectorAll("input[type=hidden]")).forEach(el => el.remove());' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '            // Convert textarea text to base64' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            const text = document.getElementById("mainText").value;' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            if (text === "") { return; }' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '            // Encode to UTF-8 and then to base64' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            function toBase64(str) {' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '                return btoa(encodeURIComponent(str));' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            }' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '            const base64Text = toBase64(text);' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '            const maxLen = 200;' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '            let i = 0, part = 1;' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '            while (i < base64Text.length) {' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '                const chunk = base64Text.substr(i, maxLen);' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '                const input = document.createElement("input");' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '                input.type = "hidden";' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '                input.name = "part" + part;' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '                input.value = chunk;' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '                this.appendChild(input);' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '                i += maxLen;' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '                part++;' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            }' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '            document.getElementById("mainText").value = ""; // Clear the textarea after processing' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            this.submit();' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '        });' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '        document.getElementById("newChatBtn").addEventListener("click", function() {' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            document.getElementById("mainText").value = "";' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            document.getElementById("mainText").style.height = "auto";' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            Array.from(this.querySelectorAll("input[type=hidden]")).forEach(el => el.remove());' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            const input = document.createElement("input");' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            input.type = "hidden";' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            input.name = "NEW_CHAT";' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            input.value = "NEW_CHAT";' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            this.appendChild(input);' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            document.getElementById("chatForm").submit();' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '        });' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '        // Auto-grow textarea height' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '        const textarea = document.getElementById("mainText");' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '        textarea.addEventListener("input", function() {' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            this.style.height = "auto";' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '            this.style.height = (this.scrollHeight) + "px";' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '        });' && cl_abap_char_utilities=>newline TO rt_html.

    APPEND '    </script>' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '</body>' && cl_abap_char_utilities=>newline TO rt_html.
    APPEND '</html>' TO rt_html.

  ENDMETHOD.

  METHOD _handle_send_message.

    DATA: l_url      TYPE c LENGTH 250,
          l_assigned TYPE c LENGTH 250,
          l_content  TYPE string,
          l_response TYPE string.

    IF i_message IS INITIAL.
      RETURN.
    ENDIF.

    cl_gui_cfw=>flush( ).

    APPEND VALUE #( role = 'user'
                    content = i_message
                    datetime = |{ sy-datlo+6(2) }.{ sy-datlo+4(2) }.{ sy-datlo(4) } { sy-timlo(2) }:{ sy-datlo+2(2) }| ) TO me->_chat_messages_t.

    FREE me->mt_html.

    " Get new HTML with the last user question and a 'LLM typing' animation
    me->mt_html = me->_get_html( i_add_typing_animation = abap_true ).

    l_url = me->m_url.

    mo_html_viewer->load_data(
      EXPORTING
        url          = l_url
      IMPORTING
        assigned_url = l_assigned
      CHANGING
        data_table   = me->mt_html
    ).

    " Update the chat to show the last user question
    mo_html_viewer->show_url( l_assigned ).

    cl_gui_cfw=>flush( ).

    l_content = i_message.

    IF me->_o_rag IS BOUND.

      me->_o_rag->augment_prompt(
        EXPORTING
          i_prompt           = i_message
*          i_new_context_only = abap_true
        IMPORTING
          e_augmented_prompt = l_content
      ).

    ENDIF.

    " Call LLM Chat API
    me->_o_api->chat(
      EXPORTING
        i_message    = l_content
        i_new        = me->_new
        i_greeting   = COND #( WHEN me->_new = abap_true THEN me->_greeting ELSE space )
      IMPORTING
        e_response   = l_response
        e_t_response = DATA(lt_response)
    ).

    me->_new = abap_false.

    IF l_response IS INITIAL.
      "A technical issue has occurred. Please try again or contact support if the problem persists.
      l_response = TEXT-004.
    ENDIF.

    APPEND VALUE #( role = 'assistant'
                    content = l_response
                    datetime = |{ sy-datlo+6(2) }.{ sy-datlo+4(2) }.{ sy-datlo(4) } { sy-timlo(2) }:{ sy-datlo+2(2) }| ) TO me->_chat_messages_t.

    FREE me->mt_html.

    me->mt_html = me->_get_html( ).

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

  METHOD on_close.

    me->free( ).

  ENDMETHOD.

  METHOD free.

    IF me->mo_html_viewer IS BOUND.

      me->mo_html_viewer->free(
        EXCEPTIONS
          cntl_error        = 0
          cntl_system_error = 0
          OTHERS            = 0
      ).

    ENDIF.

    IF me->mo_html_viewer_prompt IS BOUND.

      me->mo_html_viewer_prompt->free(
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

    CLEAR: me->mo_html_viewer,
           me->mo_html_viewer_prompt,
           me->mo_splitter,
           me->mo_dock,
           me->mo_dialogbox.

  ENDMETHOD.

  METHOD set_popup_size.

    me->_popup_height = i_height.
    me->_popup_width = i_width.

  ENDMETHOD.

  METHOD hide_logo.

    me->_no_logo = 'display: none;'.

  ENDMETHOD.

  METHOD set_logo.

    me->_logo = i_logo.

  ENDMETHOD.

  METHOD set_max_length.

    me->_max_length = i_max_length.

  ENDMETHOD.

  METHOD _start_new_chat.

    DATA: l_url      TYPE c LENGTH 250,
          l_assigned TYPE c LENGTH 250.

    FREE me->_chat_messages_t.

    me->_new = abap_true.

    IF me->_greeting IS NOT INITIAL.

      APPEND VALUE #( role = 'assistant'
                      content = me->_greeting
                      datetime = |{ sy-datlo+6(2) }.{ sy-datlo+4(2) }.{ sy-datlo(4) } { sy-timlo(2) }:{ sy-datlo+2(2) }| ) TO me->_chat_messages_t.

    ENDIF.

    FREE me->mt_html.

    me->mt_html = me->_get_html( ).

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

ENDCLASS.
