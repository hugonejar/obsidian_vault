import os
import sys
import argparse
import google.generativeai as genai
from datetime import datetime

# Initialize the Gemini API (Requires GOOGLE_API_KEY environment variable)
# export GOOGLE_API_KEY="your-api-key"
api_key = os.environ.get("GOOGLE_API_KEY")
if not api_key:
    print("❌ ERROR: GOOGLE_API_KEY environment variable not found.")
    print("Please set it using: export GOOGLE_API_KEY='your-api-key'")
    sys.exit(1)

genai.configure(api_key=api_key)

def read_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(filepath, content):
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

def generate_tailored_cv(master_cv, job_desc, template):
    print("🤖 Agent is analyzing your profile against the job description...")
    
    prompt = f"""
    You are an expert Executive Career Coach and Tech ATS Optimization Specialist. 
    Your goal is to tailor the user's Raw Experience Master Database into a targeted, highly-effective CV that perfectly aligns with the provided Job Description.

    ### 1. Raw Experience Master Database:
    {master_cv}

    ### 2. Target Job Description:
    {job_desc}

    ### 3. Output Format Template:
    {template}

    ### Instructions:
    1. **Summary:** Write a punchy, 3-4 sentence professional summary tailored EXACTLY to the job description. Highlight the intersection of the user's engineering background and the data/AI skills required for the role.
    2. **Skills:** Select and categorize the top 10-15 most relevant skills from the master database. Format them as a comma-separated list or short bullet points.
    3. **Experience:** Select the most relevant experiences. Rewrite the bullet points using the XYZ formula (Accomplished [X] as measured by [Y], by doing [Z]). Use strong action verbs. Quantify wherever possible. Ensure keywords from the job description are naturally integrated.
       - Format EACH experience block exactly like this (HTML/Markdown mix):
         <div class="job-header">
           <strong>Role Title</strong>
           <span class="date">Month Year - Month Year</span>
         </div>
         <em>Company Name</em>
         <ul>
           <li>Bullet 1</li>
           <li>Bullet 2</li>
         </ul>
    4. **Education:** Format cleanly.
    5. **Projects:** Select 1-2 projects that prove the user has the skills requested in the job description. Format similarly to experience.

    IMPORTANT: Do NOT output anything other than the final filled template. Replace the placeholders {{summary}}, {{skills}}, {{experience}}, {{education}}, and {{projects}} with the tailored content. Keep the HTML styling at the top intact. Do not wrap the output in markdown code blocks (like ```html), just output the raw code so it renders correctly in Obsidian.
    """

    model = genai.GenerativeModel('gemini-2.5-flash')
    response = model.generate_content(prompt)
    return response.text

def main():
    parser = argparse.ArgumentParser(description="Tailor a CV using Gemini AI based on a Job Description.")
    parser.add_argument('--job', type=str, required=True, help="Path to the job description markdown file.")
    args = parser.parse_args()

    base_dir = os.path.dirname(os.path.abspath(__file__))
    master_path = os.path.join(base_dir, "Raw_Experience_Master.md")
    template_path = os.path.join(base_dir, "templates", "base_template.html")
    job_path = os.path.join(base_dir, args.job)
    
    if not os.path.exists(job_path):
        print(f"❌ Job description file not found: {job_path}")
        sys.exit(1)

    master_cv = read_file(master_path)
    job_desc = read_file(job_path)
    template = read_file(template_path)

    tailored_cv = generate_tailored_cv(master_cv, job_desc, template)

    # Clean up markdown wrappers if the LLM adds them
    if tailored_cv.startswith("```html"):
        tailored_cv = tailored_cv[7:]
    if tailored_cv.startswith("```markdown"):
        tailored_cv = tailored_cv[11:]
    if tailored_cv.endswith("```"):
        tailored_cv = tailored_cv[:-3]

    # Save to outputs folder
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_filename = f"CV_Tailored_{timestamp}.md"
    output_path = os.path.join(base_dir, "outputs", output_filename)
    
    write_file(output_path, tailored_cv.strip())
    
    print(f"✅ Success! Tailored CV generated at:")
    print(f"   {output_path}")
    print("\n📝 Open this file in Obsidian, review the content, and use Obsidian's 'Export to PDF' to get your final CV.")

if __name__ == "__main__":
    main()
