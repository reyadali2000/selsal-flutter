import sys

file_path = r'C:\Users\REYADH\source\repos\WadiAlAin\WadiAlAin.Api\Controllers\DynamicReportsController.cs'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the previous mistake by removing the literal '$newMethod'
content = content.replace('\n        $newMethod\n', '')

new_method = r'''
        [HttpPost("templates")]
        public async Task<ActionResult<ApiResponse<int>>> SaveTemplate([FromBody] JsonElement body)
        {
            var (userId, username, role) = GetAuthenticatedUser();

            using var conn = _db.CreateConnection();
            conn.Open();
            using var trans = conn.BeginTransaction();

            try
            {
                int reportId = body.GetInt("id", null, 0);
                int categoryId = body.GetInt("category_id", "categoryId", 0);
                string name = body.GetString("name", null, null, "");
                string description = body.GetStringOrNull("description");
                string icon = body.GetStringOrNull("icon");
                int sortOrder = body.GetInt("sort_order", "sortOrder", 0);
                bool isActive = body.GetBoolOrNull("is_active", "isActive") ?? true;
                string approvalType = body.GetString("approval_type", "approvalType", null, "two_level");
                string orientation = body.GetString("orientation", null, null, "portrait");
                string docNumber = body.GetStringOrNull("doc_number", "docNumber");
                string versionNumber = body.GetStringOrNull("version_number", "versionNumber") ?? "01";
                string issueDate = body.GetStringOrNull("issue_date", "issueDate") ?? DateTime.UtcNow.ToString("yyyy/MM/dd");
                
                if (reportId > 0)
                {
                    await conn.ExecuteAsync(@"
                        UPDATE dr_reports SET
                            category_id = @categoryId, name = @name, description = @description,
                            icon = @icon, sort_order = @sortOrder, is_active = @isActive,
                            approval_type = @approvalType, orientation = @orientation,
                            doc_number = @docNumber, version_number = @versionNumber, issue_date = @issueDate,
                            updated_at = @now
                        WHERE id = @reportId",
                        new { reportId, categoryId, name, description, icon, sortOrder, isActive, approvalType, orientation, docNumber, versionNumber, issueDate, now = DateTime.UtcNow }, trans);

                    await conn.ExecuteAsync("DELETE FROM dr_fields WHERE report_id = @reportId", new { reportId }, trans);
                    await conn.ExecuteAsync("DELETE FROM dr_sections WHERE report_id = @reportId", new { reportId }, trans);
                }
                else
                {
                    reportId = await conn.QuerySingleAsync<int>(@"
                        INSERT INTO dr_reports (category_id, name, description, icon, sort_order, is_active, approval_type, orientation, doc_number, version_number, issue_date, created_at)
                        VALUES (@categoryId, @name, @description, @icon, @sortOrder, @isActive, @approvalType, @orientation, @docNumber, @versionNumber, @issueDate, @now);
                        SELECT CAST(SCOPE_IDENTITY() AS INT);",
                        new { categoryId, name, description, icon, sortOrder, isActive, approvalType, orientation, docNumber, versionNumber, issueDate, now = DateTime.UtcNow }, trans);
                }

                if (body.TryGetProperty("sections", out var sectionsArr) && sectionsArr.ValueKind == JsonValueKind.Array)
                {
                    foreach (var sec in sectionsArr.EnumerateArray())
                    {
                        string secTitle = sec.GetString("title", null, null, "");
                        string secDesc = sec.GetStringOrNull("description");
                        int secSort = sec.GetInt("sort_order", "sortOrder", 0);
                        bool isColl = sec.GetBoolOrNull("is_collapsible", "isCollapsible") ?? true;

                        int sectionId = await conn.QuerySingleAsync<int>(@"
                            INSERT INTO dr_sections (report_id, title, description, sort_order, is_collapsible, created_at)
                            VALUES (@reportId, @secTitle, @secDesc, @secSort, @isColl, @now);
                            SELECT CAST(SCOPE_IDENTITY() AS INT);",
                            new { reportId, secTitle, secDesc, secSort, isColl, now = DateTime.UtcNow }, trans);

                        if (sec.TryGetProperty("fields", out var fieldsArr) && fieldsArr.ValueKind == JsonValueKind.Array)
                        {
                            foreach (var fld in fieldsArr.EnumerateArray())
                            {
                                string fldKey = fld.GetString("field_key", "fieldKey", null, "");
                                string fldLabel = fld.GetString("label", null, null, "");
                                string fldHint = fld.GetStringOrNull("hint");
                                string fldType = fld.GetString("field_type", "fieldType", null, "text");
                                bool isReq = fld.GetBoolOrNull("is_required", "isRequired") ?? false;
                                int fldSort = fld.GetInt("sort_order", "sortOrder", 0);
                                string fldDefault = fld.GetStringOrNull("default_value", "defaultValue");
                                string fldOptions = fld.GetStringOrNull("options_json", "optionsJson");
                                string fldValidation = fld.GetStringOrNull("validation_json", "validationJson");
                                decimal? fldMin = fld.GetDecimalOrNull("min_value", "minValue");
                                decimal? fldMax = fld.GetDecimalOrNull("max_value", "maxValue");
                                string fldUnit = fld.GetStringOrNull("unit");
                                bool isVis = fld.GetBoolOrNull("is_visible", "isVisible") ?? true;

                                await conn.ExecuteAsync(@"
                                    INSERT INTO dr_fields (
                                        report_id, section_id, field_key, label, hint, field_type, is_required,
                                        sort_order, default_value, options_json, validation_json, min_value, max_value, unit, is_visible, created_at
                                    ) VALUES (
                                        @reportId, @sectionId, @fldKey, @fldLabel, @fldHint, @fldType, @isReq,
                                        @fldSort, @fldDefault, @fldOptions, @fldValidation, @fldMin, @fldMax, @fldUnit, @isVis, @now
                                    )",
                                    new { reportId, sectionId, fldKey, fldLabel, fldHint, fldType, isReq, fldSort, fldDefault, fldOptions, fldValidation, fldMin, fldMax, fldUnit, isVis, now = DateTime.UtcNow }, trans);
                            }
                        }
                    }
                }

                trans.Commit();
                return Ok(ApiResponse<int>.Ok(reportId));
            }
            catch (Exception ex)
            {
                trans.Rollback();
                return StatusCode(500, ApiResponse<int>.Fail($"حدث خطأ أثناء حفظ القالب: {ex.Message}"));
            }
        }
'''

content = content.replace('[HttpGet("templates")]', new_method + '\n\n        [HttpGet("templates")]')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
