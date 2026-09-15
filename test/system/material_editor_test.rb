require "application_system_test_case"

class MaterialEditorTest < ApplicationSystemTestCase
  test "administrator builds an article from ordered text and image blocks" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")

    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name
    visit new_organization_course_material_path(organizations(:one), course)

    fill_in "Title", with: "Inside a cell"
    fill_in "Card description", with: "Learn how structures inside cells work together."
    attach_file "Card cover image", Rails.root.join("public/icon.png")
    fill_editor(all("[contenteditable]").first, "<p>Cells contain several structures.</p>")
    select_editor_text(all("[contenteditable]").first)
    click_button "Title"
    select_editor_text(all("[contenteditable]").first)
    click_button "Red"

    click_button "Add image"
    within all(".material-block").last do
      attach_file "Choose image", Rails.root.join("public/icon.png")
      click_button "Move up"
      click_button "Move down"
    end

    click_button "Add text"
    fill_editor(all("[contenteditable]").last, "<p>Each structure has a specific function.</p>")

    click_button "Add text"
    within all(".material-block").last do
      click_button "Remove"
    end

    click_button "Create Material"

    assert_text "Material created."
    assert_text "Learn how structures inside cells work together."
    assert_equal %w[div figure div], all(".material-article > *").map(&:tag_name)
    assert_text "Cells contain several structures."
    assert_text "Each structure has a specific function."
    assert_selector ".material-article h2", text: "Cells contain several structures."
    assert_equal "rgb(185, 28, 28)", find(".material-article [style]").evaluate_script("getComputedStyle(this).color")

    material = course.materials.find_by!(title: "Inside a cell")
    assert_equal %w[text image text], material.blocks.pluck(:block_type)
    assert material.blocks.second.image.attached?
    assert material.cover_image.attached?
  end

  private
    def fill_editor(editor, html)
      page.execute_script("arguments[0].innerHTML = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true }))", editor, html)
    end

    def select_editor_text(editor)
      page.execute_script(<<~JAVASCRIPT, editor)
        const range = document.createRange()
        range.selectNodeContents(arguments[0])
        const selection = window.getSelection()
        selection.removeAllRanges()
        selection.addRange(range)
      JAVASCRIPT
    end
end
