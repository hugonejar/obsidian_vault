# 📄 AI CV Generator Project

Welcome to your personal AI Career Coach and Tech ATS Optimizer!

This project allows you to maintain **one single master database** of all your life's experiences, and then dynamically generate a highly-targeted, ATS-friendly CV based on a specific job description.

## 🗂 Folder Structure
- `Raw_Experience_Master.md`: **Edit this file!** Dump all your work history, projects, metrics, and skills here. Don't worry about keeping it short; this is a database, not the final CV.
- `job_descriptions/`: Paste the job description of the role you are applying for in a `.md` file here.
- `templates/base_template.html`: The layout of your CV. It mixes Markdown and inline CSS so that when you "Export to PDF" from Obsidian, it looks beautiful and professional.
- `generate_cv.py`: The Python Agent that reads your raw data and the job description, and uses the Gemini AI to write the perfect CV.
- `outputs/`: Where your generated CVs will be saved.

## 🚀 How to Use

1. **Update your Master Database:** Make sure `Raw_Experience_Master.md` has your latest data.
2. **Add a Job Description:** Create a new file in `job_descriptions/` (e.g., `vammo_data_scientist.md`) and paste the job ad.
3. **Set your API Key:** Ensure your terminal has the Google Gemini API key exported:
   ```bash
   export GOOGLE_API_KEY="your-api-key"
   ```
4. **Run the Generator:**
   Open your terminal, navigate to this folder, and run:
   ```bash
   python generate_cv.py --job "job_descriptions/example_job.md"
   ```
5. **Review & Export:**
   The agent will create a new file in the `outputs/` folder. Open it in Obsidian. Review the content (the AI will have formatted your bullets using the XYZ formula). Click the `...` menu in Obsidian and select **"Export to PDF"**.
