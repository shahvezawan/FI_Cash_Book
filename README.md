# **SAP Adobe Form Creation Guide:**  **Cash Book (ZFI\_CASH\_BOOK)**

This repository/documentation provides a step-by-step operational guide for creating and configuring the **Cash Book Adobe Form** (ZFI\_CASH\_BOOK), its associated ABAP driver program, and data structures in SAP.

## **📋 Overview**

The Cash Book Report displays financial transactions from ACDOCA for specified House Bank accounts and posting date ranges, joined with PAYR to retrieve Cheque numbers. It calculates running balances, total receipts, total payments, and displays opening and closing balances.

## **1\. Data Dictionary Objects (SE11)**

Create the following Data Dictionary objects prior to creating the Form Interface.

### **1.1 Header Structure: ZFI\_CASH\_BOOK\_HDR**

| Field Name | Data Element / Type | Description |
| :---- | :---- | :---- |
| COMPANY\_CODE | RBUKRS | Company Code |
| PERIOD\_FROM | BUDAT | Selection Start Date |
| PERIOD\_TO | BUDAT | Selection End Date |
| ACCOUNT\_NUM | BANKN | Bank Account Number |
| ACCOUNT\_TITLE | TEXT1\_012T | Bank Account Title |
| BANK\_NAME | BANKA | Bank Name |
| OPENING\_BAL | HSLXX | Opening Balance |
| TOTAL\_RECEIPT | HSLXX | Total Receipts for the Period |
| TOTAL\_PAYMENT | HSLXX | Total Payments for the Period |
| CLOSING\_BAL | HSLXX | Closing Balance |
| CURRENCY | WAERS | Currency Key |

### **1.2 Item Structure: ZFI\_CASH\_BOOK\_ITM**

| Field Name | Data Element / Type | Description |
| :---- | :---- | :---- |
| SR\_NO | INT4 | Serial Number |
| TRANS\_DATE | BUDAT | Transaction / Posting Date |
| PARTICULARS | SGTXT | Line Item Description / Text |
| CHECT | CHECT | Cheque Number (from PAYR) |
| RECEIPT | HSLXX | Receipt Amount (Positive HSL) |
| PAYMENT | HSLXX | Payment Amount (Absolute Negative HSL) |
| BALANCE | HSLXX | Running Balance |
| CURRENCY | WAERS | Currency Key |

### **1.3 Table Type: ZTT\_CASH\_BOOK\_ITM**

* **Line Type:** ZFI\_CASH\_BOOK\_ITM

## **2\. SFP Interface Configuration (ZFI\_CASH\_BOOK\_IF)**

1. Open transaction SFP.  
2. Select **Interface** and enter name ZFI\_CASH\_BOOK\_IF.  
3. Under **Import Parameters**, define:  
   * IS\_HEADER TYPE ZFI\_CASH\_BOOK\_HDR  
   * IT\_ITEMS TYPE ZTT\_CASH\_BOOK\_ITM  
4. Save and **Activate**.

## **3\. Adobe Form Layout Design (ZFI\_CASH\_BOOK)**

### **3.1 Form Context Setup**

1. Open transaction SFP, select **Form**, and enter ZFI\_CASH\_BOOK.  
2. Assign Interface ZFI\_CASH\_BOOK\_IF.  
3. In the **Context** tab, drag IS\_HEADER and IT\_ITEMS into the **Form Context**.

### **3.2 Layout Setup in LiveCycle Designer**

1. **Master Page**:  
   * Add Company Logo.  
   * Header Text: "CASH BOOK".  
   * Page Numbers: Use standard Page n of m field.  
2. **Body Page Structure**:  
   * Set root body subform to **Flowed** (Top to Bottom).  
   * **Header Subform** (Positioned): Display Account Number, Account Title, Bank Name, and Period From/To.  
   * **Opening Balance Box**: Display OPENING\_BAL.  
3. **Items Table Subform** (Flowed):  
   * Drag IT\_ITEMS table into the flowed subform.  
   * Bind table to $.IT\_ITEMS.DATA\[\*\].  
   * Columns: Sr. No, Transaction Date, Particulars, Cheque No, Receipt, Payments, Balance.

## **🚀 Execution Checklist**

* \[ \] Execute SE11 structures: ZFI\_CASH\_BOOK\_HDR, ZFI\_CASH\_BOOK\_ITM, ZTT\_CASH\_BOOK\_ITM.  
* \[ \] Create & activate SFP Interface: ZFI\_CASH\_BOOK\_IF.  
* \[ \] Build & activate SFP Form Layout: ZFI\_CASH\_BOOK.  
* \[ \] Create ABAP Report: ZFI\_CASH\_BOOK.  
* \[ \] Test execution in SE38 using House Bank parameter selection.
